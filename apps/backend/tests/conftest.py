"""Test fixtures.

State-machine tests are pure-Python and always run.
API/DB tests need ``DATABASE_URL`` to point at a reachable Postgres; otherwise skipped.

Each async test gets a fresh engine so SQLAlchemy's pool doesn't cache connections
bound to a previous test's event loop. Slow but correct under pytest-asyncio's
function-scoped loops.
"""

from __future__ import annotations

import os
import uuid

import httpx
import pytest
import pytest_asyncio


def _have_db() -> bool:
    url = os.environ.get("DATABASE_URL", "")
    return url.startswith("postgresql")


needs_db = pytest.mark.skipif(not _have_db(), reason="requires DATABASE_URL pointing at Postgres")


@pytest_asyncio.fixture(autouse=True)
async def _dispose_engine_between_tests():
    """Dispose the async engine after each test so the next test's loop
    can open fresh connections."""
    yield
    try:
        from app.db import engine
        await engine.dispose()
    except Exception:
        pass


@pytest_asyncio.fixture
async def client():
    """Async HTTP client bound to the FastAPI app via ASGI transport."""
    from app.main import app

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture
def random_email() -> str:
    return f"test-{uuid.uuid4().hex[:10]}@example.com"
