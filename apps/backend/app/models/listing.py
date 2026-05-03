"""Listing — directory entry. Implements the PRD §6.3 state machine."""

from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, ENUM, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ListingStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    rejected = "rejected"
    suspended = "suspended"
    expired = "expired"
    archived = "archived"


class ListingPackage(str, enum.Enum):
    months_3 = "months_3"
    months_6 = "months_6"
    months_12 = "months_12"


# Allowed transitions per PRD §6.3.
ALLOWED_TRANSITIONS: dict[ListingStatus, set[ListingStatus]] = {
    ListingStatus.pending: {ListingStatus.active, ListingStatus.rejected},
    ListingStatus.active: {ListingStatus.suspended, ListingStatus.expired, ListingStatus.pending},
    ListingStatus.rejected: set(),
    ListingStatus.suspended: {ListingStatus.active, ListingStatus.archived},
    ListingStatus.expired: {ListingStatus.active, ListingStatus.archived},
    ListingStatus.archived: set(),
}


class Listing(Base):
    __tablename__ = "listings"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    contact_person: Mapped[str | None] = mapped_column(String(120))

    # Multi-value: a listing can appear in multiple directories and span multiple kantons
    # (PRD §5.7: single fee covers multiple directories and kantons).
    directories: Mapped[list[str]] = mapped_column(ARRAY(String(32)), nullable=False, default=list)
    kantons: Mapped[list[str]] = mapped_column(ARRAY(String(2)), nullable=False, default=list)

    category: Mapped[str | None] = mapped_column(String(64))
    sub_category: Mapped[str | None] = mapped_column(String(64))

    address: Mapped[str | None] = mapped_column(String(256))
    phone: Mapped[str | None] = mapped_column(String(64))
    phone_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(320))
    email_public: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    website: Mapped[str | None] = mapped_column(String(512))

    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(1024))

    owner_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), index=True
    )

    status: Mapped[ListingStatus] = mapped_column(
        ENUM(ListingStatus, name="listing_status"),
        default=ListingStatus.pending,
        nullable=False,
        index=True,
    )

    package: Mapped[ListingPackage | None] = mapped_column(
        ENUM(ListingPackage, name="listing_package")
    )
    paid_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    rejection_reason: Mapped[str | None] = mapped_column(String(64))
    rejection_notes: Mapped[str | None] = mapped_column(Text)

    approved_by: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # ---- State machine -------------------------------------------------

    def can_transition_to(self, target: ListingStatus) -> bool:
        return target in ALLOWED_TRANSITIONS.get(self.status, set())

    def transition_to(self, target: ListingStatus) -> None:
        if not self.can_transition_to(target):
            raise ValueError(
                f"Illegal transition {self.status.value} -> {target.value}"
            )
        self.status = target
