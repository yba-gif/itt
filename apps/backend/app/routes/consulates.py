"""Consulate routes — public list/detail + admin CRUD."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select

from app.deps import CurrentAdmin, DBSession
from app.models.consulate import Consulate

router = APIRouter(prefix="/consulates", tags=["consulates"])
admin_router = APIRouter(prefix="/admin/consulates", tags=["admin"])


# --- Schemas ---------------------------------------------------------------


class ConsulateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    city: str
    title: str
    address: str
    phone: str
    phone_display: str
    email: str | None
    website: str
    hours_summary: str
    hours_detail: str | None
    consul_name: str | None
    consul_title: str
    consul_photo_url: str | None
    sort_order: int
    updated_at: datetime


class ConsulateIn(BaseModel):
    """Used by both create (POST) and full update (PUT). For partial
    updates, send all current values with the changed field replaced."""
    city: str
    title: str
    address: str
    phone: str
    phone_display: str
    email: str | None = None
    website: str
    hours_summary: str
    hours_detail: str | None = None
    consul_name: str | None = None
    consul_title: str
    consul_photo_url: str | None = None
    sort_order: int = 0


# --- Public ----------------------------------------------------------------


@router.get("", response_model=list[ConsulateOut])
async def list_consulates(db: DBSession) -> list[ConsulateOut]:
    rows = (
        await db.execute(select(Consulate).order_by(Consulate.sort_order.asc(), Consulate.city.asc()))
    ).scalars().all()
    return [ConsulateOut.model_validate(r) for r in rows]


# --- Admin ----------------------------------------------------------------


@admin_router.post("", response_model=ConsulateOut, status_code=status.HTTP_201_CREATED)
async def create_consulate(
    payload: ConsulateIn, admin: CurrentAdmin, db: DBSession
) -> ConsulateOut:
    row = Consulate(**payload.model_dump())
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return ConsulateOut.model_validate(row)


@admin_router.put("/{consulate_id}", response_model=ConsulateOut)
async def update_consulate(
    consulate_id: UUID,
    payload: ConsulateIn,
    admin: CurrentAdmin,
    db: DBSession,
) -> ConsulateOut:
    row = await db.get(Consulate, consulate_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "consulate not found")
    for field, value in payload.model_dump().items():
        setattr(row, field, value)
    await db.commit()
    await db.refresh(row)
    return ConsulateOut.model_validate(row)


@admin_router.delete("/{consulate_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_consulate(
    consulate_id: UUID, admin: CurrentAdmin, db: DBSession
) -> None:
    row = await db.get(Consulate, consulate_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "consulate not found")
    await db.delete(row)
    await db.commit()
