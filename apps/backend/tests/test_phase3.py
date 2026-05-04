"""End-to-end smoke tests for Phase 3 (paid listings, invoices, push, uploads)."""

from __future__ import annotations

import io
import os
import uuid

import pytest
from PIL import Image

from tests.conftest import needs_db


@pytest.fixture
def admin_credentials() -> tuple[str, str]:
    return (
        os.environ.get("ADMIN_SEED_EMAIL", "bek@itt-rehber.ch"),
        os.environ.get("ADMIN_SEED_PASSWORD", "changeme"),
    )


async def _signup(client, email: str | None = None) -> dict:
    email = email or f"u{uuid.uuid4().hex[:8]}@example.com"
    r = await client.post(
        "/auth/email/signup",
        json={"email": email, "password": "Hunter2!Hunter2"},
    )
    assert r.status_code == 200, r.text
    return r.json() | {"email": email}


async def _admin_token(client, admin_credentials) -> str:
    email, password = admin_credentials
    r = await client.post("/auth/email/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@needs_db
@pytest.mark.asyncio
async def test_paid_listing_creates_invoice(client, admin_credentials):
    user = await _signup(client)
    auth = {"Authorization": f"Bearer {user['access_token']}"}

    payload = {
        "name": f"Pricing Test {uuid.uuid4().hex[:6]}",
        "directories": ["saglik"], "kantons": ["ZH"],
        "category": "Aile Hekimi",
        "email": "billing@example.com",
        "package": "months_6",
    }
    r = await client.post("/listings", headers=auth, json=payload)
    assert r.status_code == 201, r.text
    listing = r.json()
    assert listing["package"] == "months_6"
    assert listing["paid_until"] is not None
    listing_id = listing["id"]

    # Find the invoice for this listing via the admin queue
    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    r = await client.get("/admin/invoices?unpaid=true", headers=auth_admin)
    assert r.status_code == 200
    invoices = r.json()
    invoice = next((i for i in invoices if i["listing_id"] == listing_id), None)
    assert invoice is not None
    assert invoice["amount_chf"] == 100 * 100  # 100 CHF in cents
    assert invoice["package"] == "months_6"
    assert invoice["paid_at"] is None
    assert invoice["invoice_number"].startswith("ITT-")

    # Mark paid
    r = await client.post(
        f"/admin/invoices/{invoice['id']}/mark-paid",
        headers=auth_admin,
        json={"payment_method": "twint"},
    )
    assert r.status_code == 200, r.text
    paid = r.json()
    assert paid["paid_at"] is not None
    assert paid["payment_method"] == "twint"


@needs_db
@pytest.mark.asyncio
async def test_invoice_pdf_renders(client, admin_credentials):
    user = await _signup(client)
    auth = {"Authorization": f"Bearer {user['access_token']}"}

    r = await client.post("/listings", headers=auth, json={
        "name": f"PDF Test {uuid.uuid4().hex[:6]}",
        "directories": ["hukuk"], "kantons": ["BE"],
        "email": "pdftest@example.com",
        "package": "months_3",
    })
    assert r.status_code == 201
    listing_id = r.json()["id"]

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    invoices = (await client.get("/admin/invoices?unpaid=true", headers=auth_admin)).json()
    invoice = next(i for i in invoices if i["listing_id"] == listing_id)

    # Owner can fetch their own invoice
    r = await client.get(f"/invoices/{invoice['id']}", headers=auth)
    assert r.status_code == 200
    r = await client.get(f"/invoices/{invoice['id']}/pdf", headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert r.content[:4] == b"%PDF"
    assert len(r.content) > 1000  # not an empty PDF


@needs_db
@pytest.mark.asyncio
async def test_invoice_unauthorized(client):
    """A different user must not see someone else's invoice."""
    a = await _signup(client)
    auth_a = {"Authorization": f"Bearer {a['access_token']}"}
    r = await client.post("/listings", headers=auth_a, json={
        "name": f"Owner {uuid.uuid4().hex[:6]}",
        "directories": ["finans"], "kantons": ["ZH"],
        "email": "owner@example.com",
        "package": "months_3",
    })
    assert r.status_code == 201

    # Get the invoice id via admin
    from os import environ
    admin_email = environ.get("ADMIN_SEED_EMAIL", "bek@itt-rehber.ch")
    admin_password = environ.get("ADMIN_SEED_PASSWORD", "changeme")
    r = await client.post("/auth/email/login", json={"email": admin_email, "password": admin_password})
    auth_admin = {"Authorization": f"Bearer {r.json()['access_token']}"}
    invoices = (await client.get("/admin/invoices?unpaid=true", headers=auth_admin)).json()
    listing_id = r.json().get("user_id")  # just to pull something
    target = invoices[0]  # most recent unpaid

    # Different user
    b = await _signup(client)
    auth_b = {"Authorization": f"Bearer {b['access_token']}"}
    r = await client.get(f"/invoices/{target['id']}", headers=auth_b)
    assert r.status_code == 403


@needs_db
@pytest.mark.asyncio
async def test_image_upload_validates_format(client):
    user = await _signup(client)
    auth = {"Authorization": f"Bearer {user['access_token']}"}

    # Build a valid in-memory PNG
    img = Image.new("RGB", (400, 400), color=(180, 200, 220))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    files = {"file": ("logo.png", buf.read(), "image/png")}

    r = await client.post("/uploads/image", headers=auth, files=files)
    assert r.status_code == 200, r.text
    assert "image_url" in r.json()
    assert r.json()["image_url"].endswith(".jpg")  # normalized to jpeg

    # Reject non-image content
    r = await client.post(
        "/uploads/image",
        headers=auth,
        files={"file": ("not.png", b"hello", "image/png")},
    )
    assert r.status_code == 400  # not_an_image

    # Reject too-small image
    small = Image.new("RGB", (100, 100), color="red")
    bsmall = io.BytesIO()
    small.save(bsmall, format="JPEG")
    r = await client.post(
        "/uploads/image",
        headers=auth,
        files={"file": ("tiny.jpg", bsmall.getvalue(), "image/jpeg")},
    )
    assert r.status_code == 400  # image_too_small


@needs_db
@pytest.mark.asyncio
async def test_push_register_and_broadcast(client, admin_credentials):
    user = await _signup(client)
    auth = {"Authorization": f"Bearer {user['access_token']}"}
    token = "a" * 64
    r = await client.post(
        "/push/register",
        headers=auth,
        json={"token": token, "categories": ["events", "editorial"], "kanton": "ZH"},
    )
    assert r.status_code == 204

    # Re-register same token (idempotent upsert)
    r = await client.post(
        "/push/register",
        headers=auth,
        json={"token": token, "categories": ["editorial"], "kanton": "ZH"},
    )
    assert r.status_code == 204

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    r = await client.post(
        "/admin/push/broadcast",
        headers=auth_admin,
        json={"title": "Test", "body": "Hi", "category": "editorial", "kanton": "ZH"},
    )
    assert r.status_code == 200
    body = r.json()
    # `targeted` >= 1 because we have a registered ZH+editorial token
    assert body["targeted"] >= 1
    # `sent` is 0 because APNs isn't configured in tests — the logger fallback
    # reports 0 successful APNs sends.
    assert body["sent"] == 0


@needs_db
@pytest.mark.asyncio
async def test_renewal_state_machine_via_script(client, admin_credentials):
    """Smoke: directly transition a listing to expired and verify it's hidden."""
    from datetime import UTC, datetime, timedelta
    from uuid import UUID

    from app.db import SessionLocal
    from app.models.listing import Listing as ListingModel, ListingStatus

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    r = await client.post("/listings", headers=auth_admin, json={
        "name": f"Renewal {uuid.uuid4().hex[:6]}",
        "directories": ["isletme"], "kantons": ["ZH"],
        "email": "renew@example.com",
    })
    listing_id = r.json()["id"]
    await client.post(f"/admin/listings/{listing_id}/approve", headers=auth_admin)

    async with SessionLocal() as session:
        listing = await session.get(ListingModel, UUID(listing_id))
        listing.paid_until = datetime.now(UTC) - timedelta(days=1)
        listing.transition_to(ListingStatus.expired)
        await session.commit()

    # Public list excludes expired listings
    r = await client.get("/listings", params={"directory": "isletme", "kanton": "ZH"})
    assert all(it["id"] != listing_id for it in r.json()["items"])
