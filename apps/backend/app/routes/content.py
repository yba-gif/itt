"""ContentPage routes — public read by slug, admin update."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.deps import CurrentAdmin, DBSession
from app.models.content_page import ContentPage
from app.schemas.content import ContentPageOut, ContentPageUpdateIn

router = APIRouter(prefix="/content", tags=["content"])


@router.get("", response_model=list[ContentPageOut])
async def list_pages(db: DBSession) -> list[ContentPageOut]:
    rows = (await db.execute(select(ContentPage).order_by(ContentPage.slug))).scalars().all()
    return [ContentPageOut.model_validate(r) for r in rows]


@router.get("/{slug}", response_model=ContentPageOut)
async def get_page(slug: str, db: DBSession) -> ContentPageOut:
    page = await db.get(ContentPage, slug)
    if page is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    return ContentPageOut.model_validate(page)


@router.put("/{slug}", response_model=ContentPageOut)
async def update_page(
    slug: str,
    payload: ContentPageUpdateIn,
    admin: CurrentAdmin,
    db: DBSession,
) -> ContentPageOut:
    page = await db.get(ContentPage, slug)
    if page is None:
        page = ContentPage(slug=slug, title=payload.title, body_markdown=payload.body_markdown)
        db.add(page)
    else:
        page.title = payload.title
        page.body_markdown = payload.body_markdown
        page.updated_at = datetime.now(UTC)
    page.updated_by = admin.id
    await db.commit()
    await db.refresh(page)
    return ContentPageOut.model_validate(page)
