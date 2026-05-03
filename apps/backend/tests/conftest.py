"""Test fixtures.

State-machine tests are pure-Python and always run.
API/DB tests need ``DATABASE_URL`` to point at a reachable Postgres; otherwise skipped.
"""

from __future__ import annotations

import asyncio
import os
import uuid

import httpx
import pytest
import pytest_asyncio


def _have_db() -> bool:
    url = os.environ.get("DATABASE_URL", "")
    return url.startswith("postgresql")


needs_db = pytest.mark.skipif(not _have_db(), reason="requires DATABASE_URL pointing at Postgres")


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def client():
    """Async HTTP client bound to the FastAPI app via ASGI transport."""
    from app.main import app

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture
def random_email() -> str:
    return f"test-{uuid.uuid4().hex[:10]}@example.com"
