"""Listing request/response shapes."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, HttpUrl

from app.models.listing import ListingPackage, ListingStatus

DIRECTORY_CODES = {
    "saglik",
    "hukuk",
    "isletme",
    "finans",
    "tercume",
    "meslek",
    "okullar",
    "camiler",
    "mezunlar",
    "destek_dersi",
}


class ListingIn(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    contact_person: str | None = Field(default=None, max_length=120)
    directories: list[str] = Field(min_length=1)
    kantons: list[str] = Field(min_length=1)
    category: str | None = Field(default=None, max_length=64)
    sub_category: str | None = Field(default=None, max_length=64)
    address: str | None = Field(default=None, max_length=256)
    phone: str | None = Field(default=None, max_length=64)
    phone_public: bool = True
    email: EmailStr | None = None
    email_public: bool = True
    website: HttpUrl | None = None
    description: str | None = Field(default=None, max_length=500)
    image_url: str | None = Field(default=None, max_length=1024)


class ListingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    contact_person: str | None
    directories: list[str]
    kantons: list[str]
    category: str | None
    sub_category: str | None
    address: str | None
    phone: str | None
    phone_public: bool
    email: str | None
    email_public: bool
    website: str | None
    description: str | None
    image_url: str | None
    status: ListingStatus
    package: ListingPackage | None
    paid_until: datetime | None
    created_at: datetime
    updated_at: datetime


class ListingPublicOut(BaseModel):
    """Public-facing listing — strips contact fields the provider chose to hide."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    directories: list[str]
    kantons: list[str]
    category: str | None
    sub_category: str | None
    address: str | None
    phone: str | None  # masked at the route layer if phone_public is False
    email: str | None  # masked at the route layer if email_public is False
    website: str | None
    description: str | None
    image_url: str | None
    updated_at: datetime


class ListingListOut(BaseModel):
    items: list[ListingPublicOut]
    total: int
    page: int
    page_size: int


class RejectIn(BaseModel):
    reason_code: str = Field(min_length=2, max_length=64)
    notes: str | None = Field(default=None, max_length=2000)
