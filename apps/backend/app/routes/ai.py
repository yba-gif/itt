"""İTT AI — server-side OpenAI proxy with Gemini-compatible client API.

The iOS app speaks Gemini's wire format (contents[]/system_instruction/parts).
This module:
  1. Accepts that Gemini-shaped request body
  2. Translates to OpenAI Chat Completions format
  3. Calls OpenAI's streaming endpoint with our server-side OPENAI_API_KEY
  4. Re-emits OpenAI SSE chunks as Gemini-shaped SSE chunks so the iOS
     parser (which expects `data: {"candidates":[{"content":{"parts":[{"text":…}]}}]}`)
     keeps working untouched.

This keeps the iOS contract stable across provider swaps. If we move back
to Gemini later, only this file changes.

Usage:
    POST /ai/chat
    Body: { contents: [...], system_instruction: {...}, generationConfig: {...} }
    Response: text/event-stream (Gemini-shaped SSE)
"""

from __future__ import annotations

import json
import logging
from uuid import UUID

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import update as sql_update

from app.config import settings
from app.db import SessionLocal
from app.models.ai_question import AIQuestion

router = APIRouter(prefix="/ai", tags=["ai"])
_log = logging.getLogger(__name__)

_OPENAI_MODEL = "gpt-4o-mini"
_OPENAI_URL = "https://api.openai.com/v1/chat/completions"


class ChatRequest(BaseModel):
    contents: list[dict]
    system_instruction: dict | None = None
    generationConfig: dict | None = None


# --- Gemini ↔ OpenAI translation helpers --------------------------------


def _extract_text_from_parts(parts: list[dict]) -> str:
    """Gemini's `parts` is a list of {text: str} (and possibly other media we ignore)."""
    out: list[str] = []
    for p in parts or []:
        if isinstance(p, dict) and "text" in p and isinstance(p["text"], str):
            out.append(p["text"])
    return "".join(out)


def _gemini_to_openai_messages(body: ChatRequest) -> list[dict]:
    """Translate the Gemini-shaped request to OpenAI messages[]."""
    messages: list[dict] = []

    # System instruction → role=system
    if body.system_instruction:
        sys_parts = body.system_instruction.get("parts") if isinstance(body.system_instruction, dict) else None
        if sys_parts:
            sys_text = _extract_text_from_parts(sys_parts)
            if sys_text:
                messages.append({"role": "system", "content": sys_text})

    # contents[] → user/assistant turns
    # Gemini uses role="model" for assistant; OpenAI uses role="assistant".
    for turn in body.contents or []:
        if not isinstance(turn, dict):
            continue
        role = turn.get("role", "user")
        text = _extract_text_from_parts(turn.get("parts") or [])
        if not text:
            continue
        messages.append({
            "role": "assistant" if role == "model" else "user",
            "content": text,
        })

    return messages


def _openai_to_gemini_sse(text_chunk: str) -> bytes:
    """Wrap a plain text chunk in the Gemini SSE envelope the iOS parser expects."""
    payload = {"candidates": [{"content": {"parts": [{"text": text_chunk}]}}]}
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n".encode("utf-8")


async def _insert_question(question: str) -> UUID | None:
    """Insert one row for this question BEFORE the stream starts so we still
    have a record if the client disconnects mid-stream (in which case the
    streaming generator's post-stream cleanup never runs). Returns the row id
    so we can update response_chars once the stream completes."""
    if not question:
        return None
    try:
        async with SessionLocal() as session:
            row = AIQuestion(
                question=question[:4000],  # keep table tidy
                response_chars=0,
            )
            session.add(row)
            await session.commit()
            return row.id
    except Exception as exc:  # noqa: BLE001 — logging shouldn't break the proxy
        _log.warning("ai_questions insert failed: %s", exc)
        return None


async def _update_response_chars(row_id: UUID | None, response_chars: int) -> None:
    """Update the existing row with the final response_chars count.
    Best-effort — runs only on natural stream completion. If the client
    disconnected, the row stays at response_chars=0 (which the admin UI
    highlights as "Hata" — exactly the signal we want)."""
    if row_id is None or response_chars <= 0:
        return
    try:
        async with SessionLocal() as session:
            await session.execute(
                sql_update(AIQuestion)
                .where(AIQuestion.id == row_id)
                .values(response_chars=response_chars)
            )
            await session.commit()
    except Exception as exc:  # noqa: BLE001
        _log.warning("ai_questions update failed: %s", exc)


# --- Route ---------------------------------------------------------------


@router.post("/chat")
async def ai_chat(body: ChatRequest) -> StreamingResponse:
    """Stream an OpenAI response to the iOS client, re-emitted in Gemini SSE form."""
    if not settings.openai_api_key:
        raise HTTPException(
            status_code=502,
            detail="OpenAI API key not configured on server. Set OPENAI_API_KEY.",
        )

    messages = _gemini_to_openai_messages(body)
    if not messages or messages[-1]["role"] == "system":
        raise HTTPException(status_code=400, detail="Empty conversation")

    # The user's most recent question is the last user-role message —
    # capture it for the admin log. Earlier conversation turns are context
    # we don't store separately.
    user_question = next(
        (m["content"] for m in reversed(messages) if m["role"] == "user"),
        "",
    )

    # Log the question NOW, before streaming. If the client disconnects
    # mid-stream, the generator's post-stream cleanup never runs (Starlette
    # raises GeneratorExit at the yield), so we'd otherwise lose the row.
    # See: _insert_question docstring.
    question_row_id = await _insert_question(user_question)

    # Map generationConfig → OpenAI sampling args (best-effort)
    gen = body.generationConfig or {}
    openai_payload: dict = {
        "model": _OPENAI_MODEL,
        "messages": messages,
        "stream": True,
        "temperature": gen.get("temperature", 0.8),
        "top_p": gen.get("topP", 0.95),
        "max_tokens": gen.get("maxOutputTokens", 1024),
    }

    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }

    async def _stream():
        response_chars = 0
        async with httpx.AsyncClient(timeout=45.0) as client:
            async with client.stream("POST", _OPENAI_URL, json=openai_payload, headers=headers) as resp:
                if resp.status_code != 200:
                    # Surface OpenAI errors back as a single Gemini-shaped chunk
                    error_body = await resp.aread()
                    try:
                        err = json.loads(error_body)
                        msg = err.get("error", {}).get("message", str(error_body[:200]))
                    except Exception:
                        msg = error_body.decode(errors="replace")[:200]
                    yield _openai_to_gemini_sse(f"⚠️ AI error: {msg}")
                    # Row already inserted with response_chars=0 — nothing
                    # to update on the error path.
                    return

                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    if not data_str:
                        continue
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue
                    choices = chunk.get("choices") or []
                    if not choices:
                        continue
                    delta = choices[0].get("delta") or {}
                    text_piece = delta.get("content")
                    if not text_piece:
                        continue
                    response_chars += len(text_piece)
                    yield _openai_to_gemini_sse(text_piece)

            # Stream completed naturally — update the row with the actual
            # response_chars count. (If we never get here because the client
            # disconnected, the row simply stays at response_chars=0, which
            # the admin UI flags as "Hata".)
            await _update_response_chars(question_row_id, response_chars)

    return StreamingResponse(_stream(), media_type="text/event-stream")
