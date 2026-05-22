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
_GEMINI_MODEL = "gemini-1.5-flash"
_GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{_GEMINI_MODEL}"
    ":streamGenerateContent?alt=sse"
)


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
    """Stream an AI response to the iOS client in Gemini SSE form.

    Primary: OpenAI (gpt-4o-mini). Fallback: Gemini (gemini-1.5-flash) if
    the primary fails BEFORE yielding any chunk. Once the primary has
    yielded text we don't fall back mid-stream — the client already has
    partial output and switching providers would mash two voices together.
    """
    if not settings.openai_api_key and not settings.gemini_api_key:
        raise HTTPException(
            status_code=502,
            detail="No AI provider configured. Set OPENAI_API_KEY or GEMINI_API_KEY.",
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

    gen = body.generationConfig or {}
    openai_payload: dict = {
        "model": _OPENAI_MODEL,
        "messages": messages,
        "stream": True,
        "temperature": gen.get("temperature", 0.8),
        "top_p": gen.get("topP", 0.95),
        "max_tokens": gen.get("maxOutputTokens", 1024),
    }
    openai_headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }

    # Gemini speaks the iOS client's native wire format — just pass body through.
    gemini_payload = body.model_dump(exclude_none=True)
    gemini_url_with_key = f"{_GEMINI_URL}&key={settings.gemini_api_key}"

    async def _stream():
        response_chars = 0
        openai_yielded_any = False

        # --- Primary: OpenAI ---------------------------------------------
        openai_succeeded = False
        if settings.openai_api_key:
            try:
                async with httpx.AsyncClient(timeout=45.0) as client:
                    async with client.stream(
                        "POST", _OPENAI_URL, json=openai_payload, headers=openai_headers
                    ) as resp:
                        if resp.status_code == 200:
                            async for line in resp.aiter_lines():
                                if not line or not line.startswith("data:"):
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
                                openai_yielded_any = True
                                yield _openai_to_gemini_sse(text_piece)
                            openai_succeeded = True
                        else:
                            error_body = await resp.aread()
                            _log.warning(
                                "OpenAI non-200 (%s): %s — falling back to Gemini",
                                resp.status_code, error_body[:200],
                            )
            except Exception as exc:  # noqa: BLE001
                if openai_yielded_any:
                    # Mid-stream death after we already yielded — can't
                    # safely fall back, the client has half a response.
                    _log.warning("OpenAI mid-stream failure: %s", exc)
                    yield _openai_to_gemini_sse(" …(bağlantı koptu)")
                    await _update_response_chars(question_row_id, response_chars)
                    return
                _log.warning("OpenAI failed before yielding: %s — falling back to Gemini", exc)

        if openai_succeeded:
            await _update_response_chars(question_row_id, response_chars)
            return

        # --- Fallback: Gemini --------------------------------------------
        if not settings.gemini_api_key:
            # No fallback available. Surface a friendly error.
            yield _openai_to_gemini_sse(
                "⚠️ AI hatası: OpenAI yanıt vermedi ve Gemini yedeği yapılandırılmadı."
            )
            return

        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                async with client.stream(
                    "POST",
                    gemini_url_with_key,
                    json=gemini_payload,
                    headers={"Content-Type": "application/json"},
                ) as resp:
                    if resp.status_code != 200:
                        err_body = (await resp.aread())[:300].decode(errors="replace")
                        _log.warning("Gemini fallback non-200 (%s): %s", resp.status_code, err_body)
                        yield _openai_to_gemini_sse(
                            f"⚠️ AI hatası (Gemini): {err_body[:200]}"
                        )
                        return

                    async for line in resp.aiter_lines():
                        if not line or not line.startswith("data:"):
                            continue
                        data_str = line[5:].strip()
                        if not data_str:
                            continue
                        try:
                            chunk = json.loads(data_str)
                        except json.JSONDecodeError:
                            continue
                        # Gemini's chunk: {"candidates":[{"content":{"parts":[{"text":"…"}]}}]}
                        cands = chunk.get("candidates") or []
                        if not cands:
                            continue
                        parts = (cands[0].get("content") or {}).get("parts") or []
                        text_piece = "".join(
                            p.get("text", "") for p in parts
                            if isinstance(p, dict) and isinstance(p.get("text"), str)
                        )
                        if not text_piece:
                            continue
                        response_chars += len(text_piece)
                        # Re-emit in our canonical Gemini-shaped envelope so the
                        # iOS parser handles fallback chunks the same as primary.
                        yield _openai_to_gemini_sse(text_piece)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Gemini fallback failed: %s", exc)
            yield _openai_to_gemini_sse(
                "⚠️ AI hatası: hem OpenAI hem Gemini yanıt vermedi."
            )
            return

        await _update_response_chars(question_row_id, response_chars)

    return StreamingResponse(_stream(), media_type="text/event-stream")
