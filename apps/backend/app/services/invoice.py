"""Invoice service — PDF generation, TWINT QR, sequential numbering.

PRD §5.7: invoices are server-generated PDFs with ITT branding, MwSt info if
applicable, and payment instructions for TWINT and bank transfer.

Numbering: ``ITT-YYYY-NNNNN``, sequential per year (resets at year boundary).
"""

from __future__ import annotations

import io
from datetime import UTC, datetime, timedelta
from uuid import UUID

import qrcode
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invoice import Invoice
from app.models.listing import Listing, ListingPackage
from app.services.pricing import (
    PACKAGE_AMOUNT_CENTS,
    PACKAGE_DURATION_DAYS,
    package_label_tr,
)
from app.services.storage import public_url, s3_client
from app.config import settings

# Hardcoded for now — would be admin-configurable in Phase 4.
PAYEE_NAME = "Roar (Yusuf Berkan Altun)"
PAYEE_ADDRESS = "Switzerland"
TWINT_PHONE = "+41 79 000 00 00"  # placeholder — to be replaced with real TWINT-registered number
BANK_IBAN = "CH00 0000 0000 0000 0000 0"  # placeholder
BANK_NAME = "Bank TBD"


async def next_invoice_number(session: AsyncSession) -> str:
    """ITT-2026-00001 sequential per calendar year."""
    year = datetime.now(UTC).year
    prefix = f"ITT-{year}-"
    count = (
        await session.execute(
            select(func.count())
            .select_from(Invoice)
            .where(Invoice.invoice_number.startswith(prefix))
        )
    ).scalar_one()
    return f"{prefix}{(count + 1):05d}"


def _make_twint_payload(amount_cents: int, invoice_number: str) -> str:
    """Encode TWINT-style payload as a generic URI for the QR.

    A real TWINT QR uses TWINT's commercial API. Until that's set up, embed
    a `twint://` placeholder so the QR is scannable as a URL by phones with
    TWINT installed; otherwise it falls back to a plain string the user can
    copy into the TWINT app manually. This is intentionally a placeholder
    documented in docs/architecture.md.
    """
    chf = amount_cents / 100
    return f"twint://payment?amount={chf:.2f}&currency=CHF&reference={invoice_number}"


def _qr_png_bytes(text: str, size: int = 300) -> bytes:
    qr = qrcode.QRCode(version=None, box_size=10, border=2)
    qr.add_data(text)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def render_invoice_pdf(
    *,
    invoice_number: str,
    listing: Listing,
    amount_cents: int,
    package: ListingPackage,
    issued_at: datetime,
    due_at: datetime,
) -> bytes:
    """Render the invoice PDF and return raw bytes."""
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    width, height = A4

    # Header
    c.setFont("Helvetica-Bold", 22)
    c.drawString(20 * mm, height - 25 * mm, "ITT-Rehber")
    c.setFont("Helvetica", 10)
    c.drawString(20 * mm, height - 32 * mm, "Türk topluluğu rehberi — İsviçre")

    # Invoice meta (right-aligned)
    c.setFont("Helvetica-Bold", 14)
    c.drawRightString(width - 20 * mm, height - 25 * mm, f"FATURA / RECHNUNG")
    c.setFont("Helvetica", 10)
    c.drawRightString(width - 20 * mm, height - 32 * mm, f"No: {invoice_number}")
    c.drawRightString(width - 20 * mm, height - 38 * mm, f"Tarih: {issued_at.strftime('%d.%m.%Y')}")
    c.drawRightString(width - 20 * mm, height - 44 * mm, f"Vade: {due_at.strftime('%d.%m.%Y')}")

    # Divider
    c.setStrokeColor(colors.grey)
    c.line(20 * mm, height - 50 * mm, width - 20 * mm, height - 50 * mm)

    # Bill-to
    y = height - 60 * mm
    c.setFont("Helvetica-Bold", 11)
    c.drawString(20 * mm, y, "Alıcı")
    c.setFont("Helvetica", 10)
    y -= 6 * mm
    c.drawString(20 * mm, y, listing.name)
    if listing.contact_person:
        y -= 5 * mm
        c.drawString(20 * mm, y, f"Yetkili: {listing.contact_person}")
    if listing.address:
        y -= 5 * mm
        c.drawString(20 * mm, y, listing.address)
    if listing.email:
        y -= 5 * mm
        c.drawString(20 * mm, y, listing.email)

    # Line items table
    y -= 15 * mm
    c.setFont("Helvetica-Bold", 11)
    c.drawString(20 * mm, y, "Açıklama")
    c.drawRightString(width - 20 * mm, y, "Tutar (CHF)")
    y -= 3 * mm
    c.setStrokeColor(colors.lightgrey)
    c.line(20 * mm, y, width - 20 * mm, y)
    y -= 8 * mm

    c.setFont("Helvetica", 11)
    duration_days = PACKAGE_DURATION_DAYS[package]
    desc = (
        f"İlan paketi — {package_label_tr(package)} "
        f"({duration_days} gün; ilk 30 gün ücretsiz)"
    )
    c.drawString(20 * mm, y, desc)
    c.drawRightString(width - 20 * mm, y, f"{amount_cents / 100:.2f}")
    y -= 8 * mm

    c.setFont("Helvetica-Bold", 11)
    c.drawString(20 * mm, y, "Toplam")
    c.drawRightString(width - 20 * mm, y, f"{amount_cents / 100:.2f} CHF")

    # MwSt note
    y -= 12 * mm
    c.setFont("Helvetica-Oblique", 9)
    c.setFillColor(colors.grey)
    c.drawString(
        20 * mm, y,
        "MwSt yer almıyor — yıllık 100.000 CHF eşiği altındaki gönüllü kayıt dışı işletme.",
    )
    c.setFillColor(colors.black)

    # Payment instructions
    y -= 18 * mm
    c.setFont("Helvetica-Bold", 12)
    c.drawString(20 * mm, y, "Ödeme talimatları")
    y -= 8 * mm
    c.setFont("Helvetica", 10)

    # TWINT block
    c.drawString(20 * mm, y, "TWINT")
    c.setFont("Helvetica", 9)
    c.drawString(20 * mm, y - 5 * mm, f"Numara: {TWINT_PHONE}")
    c.drawString(20 * mm, y - 10 * mm, f"Açıklama: {invoice_number}")

    # QR code on the right
    qr_bytes = _qr_png_bytes(_make_twint_payload(amount_cents, invoice_number))
    qr_path = io.BytesIO(qr_bytes)
    from reportlab.lib.utils import ImageReader

    c.drawImage(
        ImageReader(qr_path),
        width - 60 * mm,
        y - 30 * mm,
        width=40 * mm,
        height=40 * mm,
        preserveAspectRatio=True,
        mask="auto",
    )
    c.setFont("Helvetica-Oblique", 8)
    c.drawCentredString(width - 40 * mm, y - 33 * mm, "TWINT ile tara")

    # Bank block
    y -= 25 * mm
    c.setFont("Helvetica", 10)
    c.drawString(20 * mm, y, "Banka havalesi")
    c.setFont("Helvetica", 9)
    c.drawString(20 * mm, y - 5 * mm, f"IBAN: {BANK_IBAN}")
    c.drawString(20 * mm, y - 10 * mm, f"Lehtar: {PAYEE_NAME} ({BANK_NAME})")
    c.drawString(20 * mm, y - 15 * mm, f"Açıklama: {invoice_number}")

    # Footer
    c.setFont("Helvetica-Oblique", 8)
    c.setFillColor(colors.grey)
    c.drawCentredString(
        width / 2, 18 * mm,
        "İlan ücretleri iade edilmez. ITT-Rehber, listelenen profesyonellerin uzmanlığını doğrulamaz.",
    )
    c.drawCentredString(
        width / 2, 14 * mm,
        f"{PAYEE_NAME} — {PAYEE_ADDRESS}",
    )
    c.setFillColor(colors.black)

    c.showPage()
    c.save()
    return buf.getvalue()


def upload_invoice_pdf(invoice_number: str, pdf_bytes: bytes) -> str:
    """Upload PDF to S3/R2/MinIO and return the public URL."""
    key = f"invoices/{invoice_number}.pdf"
    s3_client().put_object(
        Bucket=settings.s3_bucket,
        Key=key,
        Body=pdf_bytes,
        ContentType="application/pdf",
    )
    return public_url(key)


async def issue_invoice(
    session: AsyncSession,
    listing: Listing,
    package: ListingPackage,
) -> Invoice:
    """Generate, upload, and persist a new invoice for a listing.

    First-month-free is honored: due_at is 30 days out (the start of the
    paid period), so the user has the free month to pay.
    """
    invoice_number = await next_invoice_number(session)
    amount = PACKAGE_AMOUNT_CENTS[package]
    issued_at = datetime.now(UTC)
    due_at = issued_at + timedelta(days=30)

    pdf_bytes = render_invoice_pdf(
        invoice_number=invoice_number,
        listing=listing,
        amount_cents=amount,
        package=package,
        issued_at=issued_at,
        due_at=due_at,
    )

    pdf_url: str | None
    try:
        pdf_url = upload_invoice_pdf(invoice_number, pdf_bytes)
    except Exception:
        # Object storage may be unavailable in dev; persist the invoice
        # without the URL — /invoices/:id.pdf falls back to in-memory render.
        pdf_url = None

    invoice = Invoice(
        listing_id=listing.id,
        invoice_number=invoice_number,
        amount_chf=amount,
        package=package.value,
        issued_at=issued_at,
        due_at=due_at,
        pdf_url=pdf_url,
    )
    session.add(invoice)
    return invoice
