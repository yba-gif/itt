"""Invoice — PDF invoice record. Phase 1: schema only, generation in Phase 3."""

from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import ENUM, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class PaymentMethod(str, enum.Enum):
    twint = "twint"
    bank = "bank"


class Invoice(Base):
    __tablename__ = "invoices"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    listing_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), index=True
    )
    invoice_number: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    amount_chf: Mapped[int] = mapped_column(Integer, nullable=False)  # in cents
    package: Mapped[str] = mapped_column(String(32), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    payment_method: Mapped[PaymentMethod | None] = mapped_column(
        ENUM(PaymentMethod, name="payment_method")
    )
    pdf_url: Mapped[str | None] = mapped_column(String(1024))
