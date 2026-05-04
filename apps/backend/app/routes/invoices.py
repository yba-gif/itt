"""Invoice routes — owner can fetch their invoice, admin can mark paid."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.deps import CurrentAdmin, CurrentUser, DBSession
from app.models.invoice import Invoice
from app.models.listing import Listing
from app.schemas.payment import InvoiceOut, MarkPaidIn
from app.services.invoice import render_invoice_pdf

router = APIRouter(prefix="/invoices", tags=["invoices"])


@router.get("/{invoice_id}", response_model=InvoiceOut)
async def get_invoice(invoice_id: UUID, user: CurrentUser, db: DBSession) -> InvoiceOut:
    invoice = await db.get(Invoice, invoice_id)
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    listing = await db.get(Listing, invoice.listing_id)
    if not user.is_admin and (listing is None or listing.owner_id != user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="forbidden")
    return InvoiceOut.model_validate(invoice)


@router.get("/{invoice_id}/pdf")
async def get_invoice_pdf(invoice_id: UUID, user: CurrentUser, db: DBSession):
    invoice = await db.get(Invoice, invoice_id)
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    listing = await db.get(Listing, invoice.listing_id)
    if not user.is_admin and (listing is None or listing.owner_id != user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="forbidden")
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="listing_missing")

    from app.models.listing import ListingPackage

    pdf_bytes = render_invoice_pdf(
        invoice_number=invoice.invoice_number,
        listing=listing,
        amount_cents=invoice.amount_chf,
        package=ListingPackage(invoice.package),
        issued_at=invoice.issued_at,
        due_at=invoice.due_at or invoice.issued_at,
    )
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{invoice.invoice_number}.pdf"'},
    )


# ---- Admin payment reconciliation ----

admin_router = APIRouter(prefix="/admin/invoices", tags=["admin"])


@admin_router.get("", response_model=list[InvoiceOut])
async def admin_list_invoices(
    admin: CurrentAdmin,
    db: DBSession,
    unpaid: bool = Query(default=True),
) -> list[InvoiceOut]:
    stmt = select(Invoice).order_by(Invoice.issued_at.desc()).limit(500)
    if unpaid:
        stmt = stmt.where(Invoice.paid_at.is_(None))
    rows = (await db.execute(stmt)).scalars().all()
    return [InvoiceOut.model_validate(r) for r in rows]


@admin_router.post("/{invoice_id}/mark-paid", response_model=InvoiceOut)
async def admin_mark_paid(
    invoice_id: UUID,
    payload: MarkPaidIn,
    admin: CurrentAdmin,
    db: DBSession,
) -> InvoiceOut:
    """Admin marks an invoice as paid after confirming TWINT/bank receipt.

    Side effect: sets the listing's paid_until based on package duration.
    """
    invoice = await db.get(Invoice, invoice_id)
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    if invoice.paid_at is not None:
        return InvoiceOut.model_validate(invoice)

    invoice.paid_at = datetime.now(UTC)
    invoice.payment_method = payload.payment_method

    listing = await db.get(Listing, invoice.listing_id)
    if listing is not None:
        from datetime import timedelta
        from app.models.listing import ListingPackage
        from app.services.pricing import PACKAGE_DURATION_DAYS

        package = ListingPackage(invoice.package)
        # First-month-free is already on paid_until at submit time; payment
        # adds the package duration on top.
        base = listing.paid_until or invoice.issued_at
        if base < datetime.now(UTC):
            base = datetime.now(UTC)
        listing.paid_until = base + timedelta(days=PACKAGE_DURATION_DAYS[package])
        listing.package = package

    await db.commit()
    await db.refresh(invoice)
    return InvoiceOut.model_validate(invoice)
