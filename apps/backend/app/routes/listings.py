"""Listing routes: public read (anonymous OK), provider write (auth required)."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, or_, select

from app.deps import CurrentUser, DBSession
from app.models.listing import Listing, ListingStatus
from app.schemas.listing import (
    DIRECTORY_CODES,
    ListingIn,
    ListingListOut,
    ListingOut,
    ListingPublicOut,
)

router = APIRouter(prefix="/listings", tags=["listings"])


def _to_public(listing: Listing) -> ListingPublicOut:
    return ListingPublicOut(
        id=listing.id,
        name=listing.name,
        directories=list(listing.directories or []),
        kantons=list(listing.kantons or []),
        category=listing.category,
        sub_category=listing.sub_category,
        address=listing.address,
        phone=listing.phone if listing.phone_public else None,
        email=listing.email if listing.email_public else None,
        website=listing.website,
        description=listing.description,
        image_url=listing.image_url,
        updated_at=listing.updated_at,
    )


def _validate_directories(codes: list[str]) -> list[str]:
    bad = [c for c in codes if c not in DIRECTORY_CODES]
    if bad:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"unknown_directories": bad, "allowed": sorted(DIRECTORY_CODES)},
        )
    return list(dict.fromkeys(codes))  # dedupe, preserve order


def _apply_inbound(listing: Listing, payload: ListingIn) -> None:
    listing.name = payload.name
    listing.contact_person = payload.contact_person
    listing.directories = _validate_directories(payload.directories)
    listing.kantons = list(dict.fromkeys(payload.kantons))
    listing.category = payload.category
    listing.sub_category = payload.sub_category
    listing.address = payload.address
    listing.phone = payload.phone
    listing.phone_public = payload.phone_public
    listing.email = str(payload.email) if payload.email else None
    listing.email_public = payload.email_public
    listing.website = str(payload.website) if payload.website else None
    listing.description = payload.description
    listing.image_url = payload.image_url


@router.get("", response_model=ListingListOut)
async def list_listings(
    db: DBSession,
    directory: str | None = Query(default=None),
    kanton: str | None = Query(default=None),
    q: str | None = Query(default=None, max_length=200),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
) -> ListingListOut:
    """Anonymous-friendly. Returns only ACTIVE listings."""

    stmt = select(Listing).where(Listing.status == ListingStatus.active)

    if directory:
        if directory not in DIRECTORY_CODES:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY, detail="unknown_directory"
            )
        stmt = stmt.where(Listing.directories.any(directory))

    if kanton:
        stmt = stmt.where(Listing.kantons.any(kanton.upper()))

    if q:
        ilike = f"%{q}%"
        stmt = stmt.where(
            or_(
                Listing.name.ilike(ilike),
                Listing.category.ilike(ilike),
                Listing.address.ilike(ilike),
                Listing.description.ilike(ilike),
            )
        )

    # Total count
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()

    rows = (
        await db.execute(
            stmt.order_by(Listing.name.asc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()

    return ListingListOut(
        items=[_to_public(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{listing_id}", response_model=ListingPublicOut)
async def get_listing(listing_id: UUID, db: DBSession) -> ListingPublicOut:
    listing = await db.get(Listing, listing_id)
    if listing is None or listing.status != ListingStatus.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    return _to_public(listing)


@router.post("", response_model=ListingOut, status_code=status.HTTP_201_CREATED)
async def create_listing(
    payload: ListingIn, user: CurrentUser, db: DBSession
) -> ListingOut:
    listing = Listing(owner_id=user.id, status=ListingStatus.pending)
    _apply_inbound(listing, payload)
    db.add(listing)
    await db.commit()
    await db.refresh(listing)
    return ListingOut.model_validate(listing)


@router.patch("/{listing_id}", response_model=ListingOut)
async def update_listing(
    listing_id: UUID, payload: ListingIn, user: CurrentUser, db: DBSession
) -> ListingOut:
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    if listing.owner_id != user.id and not user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="forbidden")

    _apply_inbound(listing, payload)

    # Owner edit re-enters review (PRD §6.3 active -> pending).
    if listing.status == ListingStatus.active:
        listing.transition_to(ListingStatus.pending)

    await db.commit()
    await db.refresh(listing)
    return ListingOut.model_validate(listing)


@router.get("/mine/all", response_model=list[ListingOut])
async def my_listings(user: CurrentUser, db: DBSession) -> list[ListingOut]:
    rows = (
        await db.execute(select(Listing).where(Listing.owner_id == user.id))
    ).scalars().all()
    return [ListingOut.model_validate(r) for r in rows]
