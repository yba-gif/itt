"""User-scoped routes: favorites and saved searches."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import delete, select

from app.deps import CurrentUser, DBSession
from app.models.favorite import Favorite
from app.models.listing import Listing, ListingStatus
from app.models.saved_search import SavedSearch
from app.schemas.listing import ListingPublicOut
from app.schemas.me import FavoriteOut, SavedSearchIn, SavedSearchOut

router = APIRouter(prefix="/me", tags=["me"])


# ---- Favorites ----

@router.get("/favorites", response_model=list[ListingPublicOut])
async def list_favorites(user: CurrentUser, db: DBSession) -> list[ListingPublicOut]:
    rows = (
        await db.execute(
            select(Listing)
            .join(Favorite, Favorite.listing_id == Listing.id)
            .where(Favorite.user_id == user.id, Listing.status == ListingStatus.active)
            .order_by(Favorite.created_at.desc())
        )
    ).scalars().all()
    return [
        ListingPublicOut(
            id=r.id, name=r.name, directories=list(r.directories or []),
            kantons=list(r.kantons or []), category=r.category, sub_category=r.sub_category,
            address=r.address, phone=r.phone if r.phone_public else None,
            email=r.email if r.email_public else None, website=r.website,
            description=r.description, image_url=r.image_url, updated_at=r.updated_at,
        )
        for r in rows
    ]


@router.put("/favorites/{listing_id}", response_model=FavoriteOut)
async def add_favorite(listing_id: UUID, user: CurrentUser, db: DBSession) -> FavoriteOut:
    listing = await db.get(Listing, listing_id)
    if listing is None or listing.status != ListingStatus.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="listing_not_found")
    existing = await db.get(Favorite, (user.id, listing_id))
    if existing is None:
        existing = Favorite(user_id=user.id, listing_id=listing_id)
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
    return FavoriteOut.model_validate(existing)


@router.delete("/favorites/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(listing_id: UUID, user: CurrentUser, db: DBSession) -> None:
    await db.execute(
        delete(Favorite).where(Favorite.user_id == user.id, Favorite.listing_id == listing_id)
    )
    await db.commit()


# ---- Saved searches ----

@router.get("/saved-searches", response_model=list[SavedSearchOut])
async def list_saved_searches(user: CurrentUser, db: DBSession) -> list[SavedSearchOut]:
    rows = (
        await db.execute(
            select(SavedSearch)
            .where(SavedSearch.user_id == user.id)
            .order_by(SavedSearch.created_at.desc())
        )
    ).scalars().all()
    return [SavedSearchOut.model_validate(r) for r in rows]


@router.post("/saved-searches", response_model=SavedSearchOut, status_code=status.HTTP_201_CREATED)
async def create_saved_search(
    payload: SavedSearchIn, user: CurrentUser, db: DBSession
) -> SavedSearchOut:
    s = SavedSearch(
        user_id=user.id,
        query=payload.query,
        filters=payload.filters,
        notify_on_new=payload.notify_on_new,
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)
    return SavedSearchOut.model_validate(s)


@router.delete("/saved-searches/{search_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_saved_search(search_id: UUID, user: CurrentUser, db: DBSession) -> None:
    s = await db.get(SavedSearch, search_id)
    if s is None or s.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    await db.delete(s)
    await db.commit()
