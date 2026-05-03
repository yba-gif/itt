"""End-to-end smoke: signup → submit Sağlık listing → admin approves → public list shows it.

Skipped unless DATABASE_URL is set; intended to run against the docker-compose Postgres.
"""

from __future__ import annotations

import os
import uuid

import pytest

from tests.conftest import needs_db


@pytest.fixture
def admin_credentials() -> tuple[str, str]:
    return (
        os.environ.get("ADMIN_SEED_EMAIL", "bek@itt-rehber.ch"),
        os.environ.get("ADMIN_SEED_PASSWORD", "changeme"),
    )


@needs_db
@pytest.mark.asyncio
async def test_full_phase1_loop(client, admin_credentials, random_email):
    # 1. Provider signup
    r = await client.post(
        "/auth/email/signup",
        json={"email": random_email, "password": "Hunter2!Hunter2", "display_name": "Provider"},
    )
    assert r.status_code == 200, r.text
    provider_token = r.json()["access_token"]
    auth_provider = {"Authorization": f"Bearer {provider_token}"}

    # 2. Provider submits a Sağlık listing
    listing_payload = {
        "name": f"Dr. Test {uuid.uuid4().hex[:6]}",
        "directories": ["saglik"],
        "kantons": ["ZH"],
        "category": "Aile Hekimi",
        "address": "Bahnhofstrasse 1, 8001 Zürich",
        "phone": "+41441234567",
        "phone_public": True,
        "email": "doctor@example.com",
        "email_public": False,
        "description": "Türkçe konuşan aile hekimi.",
    }
    r = await client.post("/listings", headers=auth_provider, json=listing_payload)
    assert r.status_code == 201, r.text
    listing = r.json()
    assert listing["status"] == "pending"
    listing_id = listing["id"]

    # 3. Admin login
    admin_email, admin_password = admin_credentials
    r = await client.post(
        "/auth/email/login", json={"email": admin_email, "password": admin_password}
    )
    assert r.status_code == 200, r.text
    assert r.json()["is_admin"] is True
    admin_token = r.json()["access_token"]
    auth_admin = {"Authorization": f"Bearer {admin_token}"}

    # 4. Admin sees pending in queue
    r = await client.get("/admin/queue?status=pending", headers=auth_admin)
    assert r.status_code == 200
    queue_ids = [item["id"] for item in r.json()]
    assert listing_id in queue_ids

    # 5. Admin approves
    r = await client.post(f"/admin/listings/{listing_id}/approve", headers=auth_admin)
    assert r.status_code == 200
    assert r.json()["status"] == "active"

    # 6. Anonymous read on public list — listing appears
    r = await client.get("/listings", params={"directory": "saglik", "kanton": "ZH"})
    assert r.status_code == 200
    body = r.json()
    found = next((it for it in body["items"] if it["id"] == listing_id), None)
    assert found is not None, "approved listing not present on public Sağlık list"
    # Email was marked private — must be hidden
    assert found["email"] is None
    # Phone was marked public — must be present
    assert found["phone"] == "+41441234567"


@needs_db
@pytest.mark.asyncio
async def test_kantons_and_categories_are_seeded(client):
    r = await client.get("/kantons")
    assert r.status_code == 200
    codes = {k["code"] for k in r.json()}
    assert {"ZH", "BE", "GE", "VD", "TI"}.issubset(codes)
    assert len(codes) == 26

    r = await client.get("/categories", params={"directory": "saglik"})
    assert r.status_code == 200
    names = {c["name_tr"] for c in r.json()}
    assert "Aile Hekimi" in names


@needs_db
@pytest.mark.asyncio
async def test_invalid_directory_rejected(client, random_email):
    r = await client.post(
        "/auth/email/signup",
        json={"email": random_email, "password": "Hunter2!Hunter2"},
    )
    token = r.json()["access_token"]
    r = await client.post(
        "/listings",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Bad Listing",
            "directories": ["NotARealDirectory"],
            "kantons": ["ZH"],
        },
    )
    assert r.status_code == 422


@needs_db
@pytest.mark.asyncio
async def test_non_admin_cannot_access_queue(client, random_email):
    r = await client.post(
        "/auth/email/signup",
        json={"email": random_email, "password": "Hunter2!Hunter2"},
    )
    token = r.json()["access_token"]
    r = await client.get(
        "/admin/queue", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 403
