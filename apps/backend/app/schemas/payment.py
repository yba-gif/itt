"""Schemas for invoices, payment reconciliation, push registration."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.invoice import PaymentMethod


class InvoiceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    listing_id: UUID
    invoice_number: str
    amount_chf: int  # cents
    package: str
    issued_at: datetime
    due_at: datetime | None
    paid_at: datetime | None
    payment_method: PaymentMethod | None
    pdf_url: str | None


class MarkPaidIn(BaseModel):
    payment_method: PaymentMethod


class PushRegisterIn(BaseModel):
    token: str = Field(min_length=20, max_length=256)
    categories: list[str] = Field(default_factory=lambda: ["events", "editorial", "my_listing"])
    kanton: str | None = Field(default=None, max_length=2)


class PushBroadcastIn(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=400)
    category: str = Field(default="editorial")  # events|editorial|saved_search|my_listing
    kanton: str | None = Field(default=None, max_length=2)


class PushBroadcastOut(BaseModel):
    sent: int
    targeted: int
