"""Consulate — Turkish diplomatic mission in Switzerland.

Migrated from hardcoded iOS data to DB-backed CRUD so admins can update
names, photos, hours, and addresses without an app rebuild.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Consulate(Base):
    __tablename__ = "consulates"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)

    # City label shown in the row + detail header ("Bern" / "Zürich")
    city: Mapped[str] = mapped_column(String(60), nullable=False)

    # Full Turkish title — "Türkiye Büyükelçiliği", "T.C. Başkonsolosluğu"
    title: Mapped[str] = mapped_column(String(120), nullable=False)

    address: Mapped[str] = mapped_column(String(256), nullable=False)

    # E.164 phone for tel:// link, and a human-friendly display version
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    phone_display: Mapped[str] = mapped_column(String(32), nullable=False)

    email: Mapped[str | None] = mapped_column(String(320))
    website: Mapped[str] = mapped_column(String(512), nullable=False)

    # Two-part hours field — short summary + optional footnote
    hours_summary: Mapped[str] = mapped_column(String(120), nullable=False)
    hours_detail: Mapped[str | None] = mapped_column(Text)

    # Consul / ambassador identity (card on detail page)
    consul_name: Mapped[str | None] = mapped_column(String(120))
    consul_title: Mapped[str] = mapped_column(String(120), nullable=False)
    consul_photo_url: Mapped[str | None] = mapped_column(String(1024))

    # Display order in the Bilgi tab list (smaller = earlier).
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, index=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
