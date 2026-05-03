"""Schemas for user-scoped resources: favorites, saved searches."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class FavoriteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    listing_id: UUID
    created_at: datetime


class SavedSearchIn(BaseModel):
    query: str | None = Field(default=None, max_length=200)
    filters: dict = Field(default_factory=dict)
    notify_on_new: bool = True


class SavedSearchOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    query: str | None
    filters: dict
    notify_on_new: bool
    created_at: datetime
