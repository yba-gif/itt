"""APNs device token registry."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    token: Mapped[str] = mapped_column(String(256), unique=True, nullable=False)
    # Comma-separated category opt-ins, per PRD §5.9:
    # "events", "editorial", "saved_search", "my_listing"
    categories: Mapped[str] = mapped_column(String(256), default="events,editorial,my_listing", nullable=False)
    kanton: Mapped[str | None] = mapped_column(String(2))  # for "events in my kanton"
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
