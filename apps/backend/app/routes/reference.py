"""Reference data routes — kantons + categories. Anonymous-readable."""

from __future__ import annotations

from fastapi import APIRouter, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select

from app.deps import DBSession
from app.models.category import Category
from app.models.kanton import Kanton

router = APIRouter(tags=["reference"])


class KantonOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    code: str
    name_tr: str
    name_de: str


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    directory: str
    name_tr: str


@router.get("/kantons", response_model=list[KantonOut])
async def list_kantons(db: DBSession) -> list[KantonOut]:
    rows = (await db.execute(select(Kanton).order_by(Kanton.code))).scalars().all()
    return [KantonOut.model_validate(r) for r in rows]


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(
    db: DBSession,
    directory: str | None = Query(default=None),
) -> list[CategoryOut]:
    stmt = select(Category)
    if directory:
        stmt = stmt.where(Category.directory == directory)
    rows = (await db.execute(stmt.order_by(Category.directory, Category.name_tr))).scalars().all()
    return [CategoryOut(id=str(r.id), directory=r.directory, name_tr=r.name_tr) for r in rows]
