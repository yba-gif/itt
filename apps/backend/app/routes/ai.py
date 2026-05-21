"""İTT AI — server-side Gemini proxy.

Forwards chat requests from the iOS app to Google Gemini, keeping the
API key server-side. The iOS app calls POST /ai/chat; the backend streams
the SSE response back verbatim. No conversation history is stored server-side.

Usage:
    POST /ai/chat
    Body: { contents: [...], system_instruction: {...}, generationConfig: {...} }
    Response: text/event-stream (Gemini SSE format, passed through unchanged)
"""

from __future__ import annotations

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.config import settings

router = APIRouter(prefix="/ai", tags=["ai"])

_GEMINI_MODEL = "gemini-1.5-flash"
_GEMINI_STREAM_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"{_GEMINI_MODEL}:streamGenerateContent?alt=sse"
)


class ChatRequest(BaseModel):
    contents: list[dict]
    system_instruction: dict | None = None
    generationConfig: dict | None = None


@router.post("/chat")
async def gemini_chat(body: ChatRequest) -> StreamingResponse:
    """Stream a Gemini response to the iOS client.

    The proxy strips any caller-supplied API key and uses the server-side
    GEMINI_API_KEY from environment variables. Returns 502 if the key is
    not configured.
    """
    if not settings.gemini_api_key:
        raise HTTPException(
            status_code=502,
            detail="Gemini API key not configured on server. Set GEMINI_API_KEY.",
        )

    url = f"{_GEMINI_STREAM_URL}&key={settings.gemini_api_key}"
    payload = body.model_dump(exclude_none=True)

    async def _stream() -> bytes:
        async with httpx.AsyncClient(timeout=45.0) as client:
            async with client.stream("POST", url, json=payload) as resp:
                if resp.status_code != 200:
                    # Surface Gemini errors back to the client
                    error_body = await resp.aread()
                    yield error_body
                    return
                async for chunk in resp.aiter_bytes():
                    yield chunk

    return StreamingResponse(_stream(), media_type="text/event-stream")
