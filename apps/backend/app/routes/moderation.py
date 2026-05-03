"""Admin moderation routes — queue + approve/reject."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.deps import CurrentAdmin, DBSession
from app.models.listing import Listing, ListingStatus
from app.schemas.listing import ListingOut, RejectIn

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/queue", response_model=list[ListingOut])
async def queue(
    admin: CurrentAdmin,
    db: DBSession,
    listing_status: ListingStatus = Query(default=ListingStatus.pending, alias="status"),
) -> list[ListingOut]:
    rows = (
        await db.execute(
            select(Listing)
            .where(Listing.status == listing_status)
            .order_by(Listing.created_at.asc())
            .limit(500)
        )
    ).scalars().all()
    return [ListingOut.model_validate(r) for r in rows]


@router.post("/listings/{listing_id}/approve", response_model=ListingOut)
async def approve(listing_id: UUID, admin: CurrentAdmin, db: DBSession) -> ListingOut:
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    try:
        listing.transition_to(ListingStatus.active)
    except ValueError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=str(e)) from e
    listing.approved_by = admin.id
    listing.approved_at = datetime.now(UTC)
    listing.rejection_reason = None
    listing.rejection_notes = None
    await db.commit()
    await db.refresh(listing)
    return ListingOut.model_validate(listing)


@router.post("/listings/{listing_id}/reject", response_model=ListingOut)
async def reject(
    listing_id: UUID, payload: RejectIn, admin: CurrentAdmin, db: DBSession
) -> ListingOut:
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    try:
        listing.transition_to(ListingStatus.rejected)
    except ValueError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=str(e)) from e
    listing.rejection_reason = payload.reason_code
    listing.rejection_notes = payload.notes
    await db.commit()
    await db.refresh(listing)
    return ListingOut.model_validate(listing)
