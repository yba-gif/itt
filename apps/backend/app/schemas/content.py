"""ContentPage schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ContentPageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    title: str
    body_markdown: str
    updated_at: datetime


class ContentPageUpdateIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body_markdown: str = Field(default="", max_length=200_000)
