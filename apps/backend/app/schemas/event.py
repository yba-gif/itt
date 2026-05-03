"""Event request/response shapes."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.event import EventStatus


class EventIn(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=4000)
    starts_at: datetime
    ends_at: datetime | None = None
    kanton: str = Field(min_length=2, max_length=2)
    venue: str | None = Field(default=None, max_length=200)
    address: str | None = Field(default=None, max_length=256)
    image_url: str | None = Field(default=None, max_length=1024)
    submitter_email: EmailStr | None = None


class EventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: str | None
    starts_at: datetime
    ends_at: datetime | None
    kanton: str
    venue: str | None
    address: str | None
    image_url: str | None
    status: EventStatus
    created_at: datetime


class EventListOut(BaseModel):
    items: list[EventOut]
    total: int
