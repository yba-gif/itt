"""End-to-end smoke tests for Phase 2 functionality.

Skipped unless DATABASE_URL is set.
"""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime, timedelta

import pytest

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


# ---- Events ----

@needs_db
@pytest.mark.asyncio
async def test_events_filter_excludes_past(client, admin_credentials):
    """PRD §5.3 v1 bug fix: future-only by default, past=true returns history."""
    user = await _signup(client)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}

    future = (datetime.now(UTC) + timedelta(days=7)).isoformat()
    past = (datetime.now(UTC) - timedelta(days=7)).isoformat()

    rf = await client.post("/events", headers=auth_user, json={
        "title": f"Future event {uuid.uuid4().hex[:6]}",
        "starts_at": future, "kanton": "ZH",
    })
    rp = await client.post("/events", headers=auth_user, json={
        "title": f"Past event {uuid.uuid4().hex[:6]}",
        "starts_at": past, "kanton": "ZH",
    })
    assert rf.status_code == 201 and rp.status_code == 201
    fut_id = rf.json()["id"]
    past_id = rp.json()["id"]

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}

    for eid in (fut_id, past_id):
        r = await client.post(f"/admin/events/{eid}/approve", headers=auth_admin)
        assert r.status_code == 200, r.text

    upcoming = (await client.get("/events")).json()
    assert any(it["id"] == fut_id for it in upcoming["items"])
    assert all(it["id"] != past_id for it in upcoming["items"])

    history = (await client.get("/events", params={"past": "true"})).json()
    assert any(it["id"] == past_id for it in history["items"])


@needs_db
@pytest.mark.asyncio
async def test_event_submission_anonymous_rejected_by_default(client):
    """Anonymous can submit (PRD §5.3); but it stays pending until approved."""
    future = (datetime.now(UTC) + timedelta(days=14)).isoformat()
    r = await client.post(
        "/events",
        json={
            "title": f"Anon event {uuid.uuid4().hex[:6]}",
            "starts_at": future,
            "kanton": "BE",
            "submitter_email": "anon@example.com",
        },
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["status"] == "pending"
    # Public list should NOT include pending submissions
    listing = (await client.get("/events")).json()
    assert all(it["id"] != body["id"] for it in listing["items"])


# ---- ContentPage ----

@needs_db
@pytest.mark.asyncio
async def test_content_pages_seeded(client):
    pages = (await client.get("/content")).json()
    slugs = {p["slug"] for p in pages}
    assert {"welcome", "emergency", "consulate", "privacy", "terms", "about"}.issubset(slugs)

    r = await client.get("/content/emergency")
    assert r.status_code == 200
    assert "144" in r.json()["body_markdown"]


@needs_db
@pytest.mark.asyncio
async def test_admin_can_update_content_page(client, admin_credentials):
    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    new_body = f"Updated at {uuid.uuid4().hex[:6]}"
    r = await client.put("/content/welcome", headers=auth_admin, json={
        "title": "Hoş Geldiniz", "body_markdown": new_body,
    })
    assert r.status_code == 200
    assert r.json()["body_markdown"] == new_body


# ---- Favorites ----

@needs_db
@pytest.mark.asyncio
async def test_favorites_round_trip(client, admin_credentials):
    user = await _signup(client)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}

    # Create + approve a listing
    payload = {
        "name": f"Fav target {uuid.uuid4().hex[:6]}",
        "directories": ["saglik"], "kantons": ["ZH"], "category": "Aile Hekimi",
    }
    r = await client.post("/listings", headers=auth_user, json=payload)
    assert r.status_code == 201
    listing_id = r.json()["id"]

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    r = await client.post(f"/admin/listings/{listing_id}/approve", headers=auth_admin)
    assert r.status_code == 200

    # Favorite
    r = await client.put(f"/me/favorites/{listing_id}", headers=auth_user)
    assert r.status_code == 200
    favs = (await client.get("/me/favorites", headers=auth_user)).json()
    assert any(f["id"] == listing_id for f in favs)

    # Unfavorite
    r = await client.delete(f"/me/favorites/{listing_id}", headers=auth_user)
    assert r.status_code == 204
    favs = (await client.get("/me/favorites", headers=auth_user)).json()
    assert all(f["id"] != listing_id for f in favs)


# ---- Saved searches ----

@needs_db
@pytest.mark.asyncio
async def test_saved_searches_round_trip(client):
    user = await _signup(client)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}

    r = await client.post(
        "/me/saved-searches", headers=auth_user,
        json={"query": "diş", "filters": {"directory": "saglik", "kanton": "ZH"}},
    )
    assert r.status_code == 201
    search_id = r.json()["id"]

    rows = (await client.get("/me/saved-searches", headers=auth_user)).json()
    assert any(s["id"] == search_id for s in rows)

    r = await client.delete(f"/me/saved-searches/{search_id}", headers=auth_user)
    assert r.status_code == 204


# ---- Search ----

@needs_db
@pytest.mark.asyncio
async def test_global_search_finds_listing_by_unaccented_query(client, admin_credentials):
    """`Sağlık` should match a query for `saglik` (unaccent path)."""
    user = await _signup(client)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}

    unique = uuid.uuid4().hex[:8]
    payload = {
        "name": f"Sağlık Center {unique}",
        "directories": ["saglik"], "kantons": ["ZH"],
        "category": "Diş Hekimi",
        "description": "Türkçe konuşan diş hekimliği",
    }
    r = await client.post("/listings", headers=auth_user, json=payload)
    assert r.status_code == 201
    lid = r.json()["id"]

    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}
    r = await client.post(f"/admin/listings/{lid}/approve", headers=auth_admin)
    assert r.status_code == 200

    # Search for unaccented "saglik" — should find the "Sağlık Center" listing
    r = await client.get("/search", params={"q": f"saglik {unique}"})
    assert r.status_code == 200
    body = r.json()
    found = False
    for group in body["groups"]:
        if any(it["id"] == lid for it in group["items"]):
            found = True
            break
    assert found, f"global search did not return the seeded listing: {body}"


# ---- Listing claim flow ----

@needs_db
@pytest.mark.asyncio
async def test_v1_claim_email_match(client, admin_credentials):
    """User signs up with the same email as a v1-imported listing -> can claim."""
    # Inject a v1-style imported listing directly via the DB fixture path.
    # Easiest: have an admin create a listing then null out its owner.
    admin_tok = await _admin_token(client, admin_credentials)
    auth_admin = {"Authorization": f"Bearer {admin_tok}"}

    target_email = f"claim-{uuid.uuid4().hex[:6]}@example.com"
    r = await client.post("/listings", headers=auth_admin, json={
        "name": f"v1 Provider {uuid.uuid4().hex[:6]}",
        "directories": ["saglik"], "kantons": ["ZH"],
        "email": target_email, "email_public": False,
    })
    assert r.status_code == 201
    listing_id = r.json()["id"]
    # Approve it so it's "active" and resembles a v1 import.
    r = await client.post(f"/admin/listings/{listing_id}/approve", headers=auth_admin)
    assert r.status_code == 200

    # Anonymize ownership (simulating v1 import).
    from app.db import SessionLocal
    from app.models.listing import Listing as ListingModel
    async with SessionLocal() as session:
        from uuid import UUID
        listing = await session.get(ListingModel, UUID(listing_id))
        listing.owner_id = None
        await session.commit()

    # User signs up with matching email
    user = await _signup(client, email=target_email)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}

    # /listings/claimable/mine should surface it
    rows = (await client.get("/listings/claimable/mine", headers=auth_user)).json()
    assert any(l["id"] == listing_id for l in rows)

    # Claim
    r = await client.post(f"/listings/{listing_id}/claim", headers=auth_user)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "pending"  # re-enters review

    # Wrong email shouldn't be able to claim a different listing
    other_email = f"other-{uuid.uuid4().hex[:6]}@example.com"
    r = await client.post("/listings", headers=auth_admin, json={
        "name": "v1 Other", "directories": ["hukuk"], "kantons": ["BE"],
        "email": "mismatch@example.com",
    })
    other_id = r.json()["id"]
    await client.post(f"/admin/listings/{other_id}/approve", headers=auth_admin)
    async with SessionLocal() as session:
        listing = await session.get(ListingModel, UUID(other_id))
        listing.owner_id = None
        await session.commit()
    other_user = await _signup(client, email=other_email)
    other_headers = {"Authorization": f"Bearer {other_user['access_token']}"}
    r = await client.post(f"/listings/{other_id}/claim", headers=other_headers)
    assert r.status_code == 403


# ---- Backend list filter excludes phase-1 directory restriction ----

@needs_db
@pytest.mark.asyncio
async def test_all_directories_acceptable(client):
    user = await _signup(client)
    auth_user = {"Authorization": f"Bearer {user['access_token']}"}
    for directory in [
        "saglik", "hukuk", "isletme", "finans", "tercume",
        "meslek", "okullar", "camiler", "mezunlar", "destek_dersi",
    ]:
        r = await client.post("/listings", headers=auth_user, json={
            "name": f"Phase2 {directory} {uuid.uuid4().hex[:4]}",
            "directories": [directory], "kantons": ["ZH"],
        })
        assert r.status_code == 201, f"directory {directory} rejected: {r.text}"
