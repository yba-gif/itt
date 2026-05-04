#!/usr/bin/env python3
"""Daily housekeeping for paid listings.

Run via cron (Phase 4 sets up the actual cron):
    0 9 * * * /usr/bin/python /opt/itt/scripts/expire-and-remind.py

Does three things:
  1) Mark active listings whose paid_until has passed as expired (PRD §6.3).
  2) Mark expired listings older than 90 days as archived (PRD §6.3).
  3) Email owners 30 days before expiry with a renewal CTA (PRD §5.7).
"""

from __future__ import annotations

import asyncio
import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "apps" / "backend"))

os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://itt:itt_dev@localhost:5433/itt"
)

from sqlalchemy import select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models.listing import Listing, ListingStatus  # noqa: E402
from app.services.email import send_email  # noqa: E402


async def run() -> int:
    now = datetime.now(UTC)
    cutoff_archive = now - timedelta(days=90)
    cutoff_remind = now + timedelta(days=30)

    expired_count = 0
    archived_count = 0
    reminded_count = 0

    async with SessionLocal() as session:
        # 1) active -> expired where paid_until passed
        active_rows = (
            await session.execute(
                select(Listing).where(
                    Listing.status == ListingStatus.active,
                    Listing.paid_until.is_not(None),
                    Listing.paid_until < now,
                )
            )
        ).scalars().all()
        for r in active_rows:
            try:
                r.transition_to(ListingStatus.expired)
                expired_count += 1
            except ValueError:
                pass

        # 2) expired -> archived where paid_until > 90 days ago
        old_expired = (
            await session.execute(
                select(Listing).where(
                    Listing.status == ListingStatus.expired,
                    Listing.paid_until.is_not(None),
                    Listing.paid_until < cutoff_archive,
                )
            )
        ).scalars().all()
        for r in old_expired:
            try:
                r.transition_to(ListingStatus.archived)
                archived_count += 1
            except ValueError:
                pass

        # 3) Reminders for active listings expiring in 30 days
        soon_expiring = (
            await session.execute(
                select(Listing).where(
                    Listing.status == ListingStatus.active,
                    Listing.paid_until.is_not(None),
                    Listing.paid_until > now,
                    Listing.paid_until <= cutoff_remind,
                    Listing.email.is_not(None),
                )
            )
        ).scalars().all()
        for r in soon_expiring:
            send_email(
                r.email,
                subject="ITT-Rehber: ilan yenileme zamanı yaklaşıyor",
                body_text=(
                    f"Merhaba,\n\n"
                    f"'{r.name}' adlı ilanınızın geçerliliği "
                    f"{r.paid_until:%d.%m.%Y} tarihinde sona eriyor.\n"
                    f"Yenilemek için ITT-Rehber uygulamasından profilinize girip "
                    f"İlanlarım > Yenile adımlarını izleyin."
                ),
            )
            reminded_count += 1

        await session.commit()

    print(
        f"expire-and-remind: expired={expired_count} archived={archived_count} "
        f"reminded={reminded_count}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(run()))
