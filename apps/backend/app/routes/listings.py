"""Listing routes: public read (anonymous OK), provider write (auth required)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select

from app.deps import CurrentUser, DBSession
from app.models.listing import Listing, ListingPackage, ListingStatus
from app.schemas.listing import (
    DIRECTORY_CODES,
    ListingIn,
    ListingListOut,
    ListingOut,
    ListingPublicOut,
)
from app.services.email import send_email
from app.services.invoice import issue_invoice, render_invoice_pdf
from app.services.pricing import FIRST_MONTH_FREE_DAYS, package_label_tr
from app.services.search import apply_fts

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
            status.HTTP_422_UNPROCESSABLE_CONTENT,
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
                status.HTTP_422_UNPROCESSABLE_CONTENT, detail="unknown_directory"
            )
        stmt = stmt.where(Listing.directories.any(directory))

    if kanton:
        stmt = stmt.where(Listing.kantons.any(kanton.upper()))

    if q:
        stmt = apply_fts(stmt, q)

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

    if payload.package is not None:
        listing.package = payload.package
        # First-month-free: paid_until starts at today + 30 days. Admin's
        # mark-paid extends this by the package duration.
        listing.paid_until = datetime.now(UTC) + timedelta(days=FIRST_MONTH_FREE_DAYS)

    db.add(listing)
    await db.flush()  # need listing.id before issuing invoice

    invoice = None
    if payload.package is not None:
        invoice = await issue_invoice(db, listing, payload.package)
        await db.flush()

    await db.commit()
    await db.refresh(listing)

    # Send confirmation email + invoice (best-effort — failures don't block submission).
    if invoice is not None and listing.email:
        from app.services.invoice import render_invoice_pdf  # avoid circular at top
        try:
            pdf_bytes = render_invoice_pdf(
                invoice_number=invoice.invoice_number,
                listing=listing,
                amount_cents=invoice.amount_chf,
                package=ListingPackage(invoice.package),
                issued_at=invoice.issued_at,
                due_at=invoice.due_at or invoice.issued_at,
            )
            send_email(
                listing.email,
                subject=f"ITT-Rehber: İlan başvurunuz alındı — {invoice.invoice_number}",
                body_text=(
                    f"Merhaba,\n\n"
                    f"İlanınız incelemeye alındı. Onaylandıktan sonra yayında olacak.\n\n"
                    f"Paket: {package_label_tr(payload.package)}\n"
                    f"İlk ay ücretsiz — ödeme talimatları ektedir.\n\n"
                    f"Fatura No: {invoice.invoice_number}\n"
                    f"Tutar: {invoice.amount_chf / 100:.2f} CHF\n"
                ),
                attachments=[(f"{invoice.invoice_number}.pdf", pdf_bytes, "application/pdf")],
            )
        except Exception:
            pass

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


@router.get("/claimable/mine", response_model=list[ListingPublicOut])
async def claimable_for_me(user: CurrentUser, db: DBSession) -> list[ListingPublicOut]:
    """Listings imported from v1 (owner_id IS NULL) whose email matches the user's.

    PRD §6.4 + claim-flow note: original provider signs up with the email
    associated with their listing in the v1 sheet → can claim ownership.
    """
    if not user.email:
        return []
    rows = (
        await db.execute(
            select(Listing).where(
                Listing.owner_id.is_(None),
                Listing.email == user.email,
                Listing.status.in_([ListingStatus.active, ListingStatus.suspended]),
            )
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


@router.post("/{listing_id}/claim", response_model=ListingOut)
async def claim_listing(listing_id: UUID, user: CurrentUser, db: DBSession) -> ListingOut:
    """Claim a v1-imported listing whose email matches the current user's email."""
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    if listing.owner_id is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="already_owned")
    if not listing.email or listing.email.lower() != (user.email or "").lower():
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="email_mismatch")

    listing.owner_id = user.id
    # Re-enter review per PRD §6.3 active->pending semantics, so admin can
    # confirm the ownership change before public update.
    if listing.status == ListingStatus.active:
        listing.transition_to(ListingStatus.pending)
    await db.commit()
    await db.refresh(listing)
    return ListingOut.model_validate(listing)
