"""Social — one entry in the 'Bizi Takip Edin' row on the Bilgi tab.

Migrated from hardcoded iOS data so admins can add/remove platforms
(Facebook, X, Instagram, Web, E-posta, …) without an app rebuild.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Social(Base):
    __tablename__ = "socials"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)

    # Human label shown under the chip ("Facebook", "X", "Instagram", "E-posta")
    label: Mapped[str] = mapped_column(String(40), nullable=False)

    # SF Symbol name — the icon used on the chip.
    # iOS apps will fall back to "link" if the symbol is unknown.
    system_icon: Mapped[str] = mapped_column(String(60), nullable=False)

    # Destination URL — https://, mailto:, tel:, etc.
    url: Mapped[str] = mapped_column(String(512), nullable=False)

    # Brand-ish tint, as a CSS-style hex string like "#1A5CC8" or
    # "#000000". iOS parses this into a Color.
    tint_hex: Mapped[str] = mapped_column(String(7), nullable=False, default="#B82030")

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
