"""Social routes — public list + admin CRUD for the 'Bizi Takip Edin' row."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select

from app.deps import CurrentAdmin, DBSession
from app.models.social import Social

router = APIRouter(prefix="/socials", tags=["socials"])
admin_router = APIRouter(prefix="/admin/socials", tags=["admin"])


# --- Schemas ---------------------------------------------------------------


class SocialOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    label: str
    system_icon: str
    url: str
    tint_hex: str
    sort_order: int
    updated_at: datetime


class SocialIn(BaseModel):
    label: str
    system_icon: str
    url: str
    tint_hex: str = "#B82030"
    sort_order: int = 0


# --- Public ----------------------------------------------------------------


@router.get("", response_model=list[SocialOut])
async def list_socials(db: DBSession) -> list[SocialOut]:
    rows = (
        await db.execute(select(Social).order_by(Social.sort_order.asc(), Social.label.asc()))
    ).scalars().all()
    return [SocialOut.model_validate(r) for r in rows]


# --- Admin ----------------------------------------------------------------


@admin_router.post("", response_model=SocialOut, status_code=status.HTTP_201_CREATED)
async def create_social(
    payload: SocialIn, admin: CurrentAdmin, db: DBSession
) -> SocialOut:
    row = Social(**payload.model_dump())
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return SocialOut.model_validate(row)


@admin_router.put("/{social_id}", response_model=SocialOut)
async def update_social(
    social_id: UUID,
    payload: SocialIn,
    admin: CurrentAdmin,
    db: DBSession,
) -> SocialOut:
    row = await db.get(Social, social_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "social not found")
    for field, value in payload.model_dump().items():
        setattr(row, field, value)
    await db.commit()
    await db.refresh(row)
    return SocialOut.model_validate(row)


@admin_router.delete("/{social_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_social(
    social_id: UUID, admin: CurrentAdmin, db: DBSession
) -> None:
    row = await db.get(Social, social_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "social not found")
    await db.delete(row)
    await db.commit()
