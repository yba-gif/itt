"""Global search across all listings, grouped by directory.

PRD §5.5: search is a primary feature, not a per-directory feature. Returns
results grouped by directory_code with counts.
"""

from __future__ import annotations

from fastapi import APIRouter, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select

from app.deps import DBSession
from app.models.listing import Listing, ListingStatus
from app.schemas.listing import DIRECTORY_CODES, ListingPublicOut
from app.services.search import apply_fts

router = APIRouter(prefix="/search", tags=["search"])


class GroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    directory: str
    items: list[ListingPublicOut]
    count: int


class SearchOut(BaseModel):
    query: str
    total: int
    groups: list[GroupOut]


def _to_public(r: Listing) -> ListingPublicOut:
    return ListingPublicOut(
        id=r.id, name=r.name, directories=list(r.directories or []),
        kantons=list(r.kantons or []), category=r.category, sub_category=r.sub_category,
        address=r.address, phone=r.phone if r.phone_public else None,
        email=r.email if r.email_public else None, website=r.website,
        description=r.description, image_url=r.image_url, updated_at=r.updated_at,
    )


@router.get("", response_model=SearchOut)
async def global_search(
    db: DBSession,
    q: str = Query(min_length=1, max_length=200),
    limit_per_group: int = Query(default=10, ge=1, le=50),
) -> SearchOut:
    stmt = (
        apply_fts(select(Listing).where(Listing.status == ListingStatus.active), q)
        .order_by(Listing.name)
        .limit(500)
    )
    rows: list[Listing] = list((await db.execute(stmt)).scalars().all())

    by_dir: dict[str, list[Listing]] = {}
    for r in rows:
        # A row with multi-directory membership counts in each.
        for d in (r.directories or []):
            if d not in DIRECTORY_CODES:
                continue
            by_dir.setdefault(d, []).append(r)

    groups: list[GroupOut] = []
    for directory in sorted(by_dir):
        bucket = by_dir[directory]
        groups.append(GroupOut(
            directory=directory,
            items=[_to_public(r) for r in bucket[:limit_per_group]],
            count=len(bucket),
        ))

    return SearchOut(query=q, total=len(rows), groups=groups)
