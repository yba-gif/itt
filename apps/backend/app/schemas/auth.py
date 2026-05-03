"""Auth request/response shapes."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class EmailSignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=120)


class EmailLoginIn(BaseModel):
    email: EmailStr
    password: str


class SIWAIn(BaseModel):
    identity_token: str
    display_name: str | None = Field(default=None, max_length=120)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID
    is_admin: bool


class MeOut(BaseModel):
    id: UUID
    email: str
    display_name: str | None
    is_admin: bool
    language: str
