"""AIQuestion — log of every user message to /ai/chat."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class AIQuestion(Base):
    """One row per user message sent to the AI proxy.

    Logged in /ai/chat *after* validating the OpenAI key is present, so
    we don't log spam if the AI is broken. user_id is nullable because
    the AI route doesn't require auth.
    """

    __tablename__ = "ai_questions"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)

    user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        index=True,
    )

    # Last user-role message in the conversation — i.e. the question they
    # just typed. Earlier messages provide context but aren't logged
    # separately to keep the table compact.
    question: Mapped[str] = mapped_column(Text, nullable=False)

    # Approximate character count of the assistant's streamed response.
    # Used as a rough success signal (0 = failed / no response).
    response_chars: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Short language hint, e.g. "tr", "de", "fr", "en". Optional.
    lang: Mapped[str | None] = mapped_column(String(8))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )
