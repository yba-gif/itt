#!/usr/bin/env python3
"""v1 -> v2 migration script.

PRD §6.4 + claim flow:
- v1 lives in Google Sheet 1cVUyaR2kpoYNAv1RCUt4XOIvNeIl03st8P9hd4OdAC4
- Imported listings get status=active, paid_until = launch_date + 1 month, owner_id=NULL
- Validation errors are surfaced for manual cleanup before flipping the live switch
- Original "_old" tabs preserved in source but not imported

Two ingest modes:
  --source=mock   Reads scripts/v1-mock.csv (committed) — useful for tests and demo
  --source=sheets Pulls from Google Sheets via service-account creds at $GOOGLE_APPLICATION_CREDENTIALS
                  (deferred; emits a clear error until creds are wired)

Usage:
    python scripts/migrate-from-v1.py --source=mock --dry-run
    python scripts/migrate-from-v1.py --source=mock          # commits to DB
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import os
import sys
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "apps" / "backend"))

# Default to host-side localhost:5433 BEFORE app.config is imported (Settings()
# is instantiated at import time, so this needs to happen before any app.*
# imports run).
os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://itt:itt_dev@localhost:5433/itt"
)

from sqlalchemy import select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models.listing import Listing, ListingStatus  # noqa: E402

SHEET_ID = "1cVUyaR2kpoYNAv1RCUt4XOIvNeIl03st8P9hd4OdAC4"

V1_TAB_TO_DIRECTORY: dict[str, str] = {
    "saglik": "saglik",
    "hukuk": "hukuk",
    "isletme": "isletme",
    "finans": "finans",
    "tercume": "tercume",
    "meslek": "meslek",
    "okullar": "okullar",
    "camiler_itdv": "camiler",
    "mezunlar": "mezunlar",
    "destek_dersi": "destek_dersi",
}

VALID_KANTONS = {
    "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR", "JU", "LU", "NE",
    "NW", "OW", "SG", "SH", "SO", "SZ", "TG", "TI", "UR", "VD", "VS", "ZG", "ZH",
}


@dataclass
class ImportRow:
    tab: str
    raw: dict[str, str]


@dataclass
class ImportError_:
    row_index: int
    tab: str
    message: str


def fetch_mock_rows(path: Path) -> list[ImportRow]:
    if not path.exists():
        raise FileNotFoundError(f"Mock CSV not found at {path}. Create it or use --source=sheets.")
    rows: list[ImportRow] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            tab = (raw.get("tab") or "").strip()
            if tab not in V1_TAB_TO_DIRECTORY:
                continue
            # Defensive: csv.DictReader puts extra columns under key=None as a list.
            cleaned: dict[str, str] = {}
            for k, v in raw.items():
                if k is None:
                    continue
                if isinstance(v, list):
                    v = v[0] if v else ""
                cleaned[k] = (v or "").strip()
            rows.append(ImportRow(tab=tab, raw=cleaned))
    return rows


def fetch_sheet_rows() -> list[ImportRow]:
    raise NotImplementedError(
        "--source=sheets requires GOOGLE_APPLICATION_CREDENTIALS pointing at a "
        "service-account JSON with read access to the v1 sheet. Wire this when "
        "Phase 2 launch is imminent."
    )


def parse_kantons(value: str) -> tuple[list[str], str | None]:
    """Split a kanton string ('ZH, BE') into uppercase codes; return (codes, error)."""
    if not value:
        return [], None
    parts = [p.strip().upper() for p in value.replace(";", ",").split(",") if p.strip()]
    bad = [p for p in parts if p not in VALID_KANTONS]
    if bad:
        return [], f"unknown kantons: {bad}"
    return parts, None


def map_row(row: ImportRow) -> tuple[Listing | None, list[str]]:
    """Return (listing-or-None, errors). Listing is None iff there are blocking errors."""
    errs: list[str] = []
    raw = row.raw
    name = raw.get("name", "").strip()
    if not name:
        errs.append("missing name")
    kantons, kerr = parse_kantons(raw.get("kantons", ""))
    if kerr:
        errs.append(kerr)
    if not kantons:
        errs.append("no kantons")
    if errs:
        return None, errs

    directory = V1_TAB_TO_DIRECTORY[row.tab]
    listing = Listing(
        name=name,
        contact_person=raw.get("contact_person") or None,
        directories=[directory],
        kantons=kantons,
        category=raw.get("category") or None,
        address=raw.get("address") or None,
        phone=raw.get("phone") or None,
        phone_public=True,
        email=(raw.get("email") or None),
        email_public=False,  # v1 never asked; treat as private until claimed
        website=raw.get("website") or None,
        description=raw.get("description") or None,
        image_url=raw.get("image_url") or None,
        owner_id=None,
        status=ListingStatus.active,
        paid_until=datetime.now(UTC) + timedelta(days=30),  # PRD: free first month
    )
    return listing, []


async def run(source: str, dry_run: bool) -> int:
    if source == "mock":
        rows = fetch_mock_rows(ROOT / "scripts" / "v1-mock.csv")
    elif source == "sheets":
        rows = fetch_sheet_rows()
    else:
        print(f"Unknown source: {source}", file=sys.stderr)
        return 2

    print(f"Loaded {len(rows)} rows from {source}.")
    by_tab: dict[str, int] = {}
    for r in rows:
        by_tab[r.tab] = by_tab.get(r.tab, 0) + 1
    for tab, n in sorted(by_tab.items()):
        print(f"  {tab}: {n}")

    listings: list[Listing] = []
    errors: list[ImportError_] = []
    for i, row in enumerate(rows):
        listing, errs = map_row(row)
        if errs:
            for e in errs:
                errors.append(ImportError_(row_index=i, tab=row.tab, message=e))
        elif listing is not None:
            listings.append(listing)

    print()
    print(f"Mapped: {len(listings)} listings; {len(errors)} validation errors.")
    if errors[:5]:
        print("Sample errors:")
        for e in errors[:5]:
            print(f"  row {e.row_index} [{e.tab}]: {e.message}")

    if dry_run:
        print("\n(dry-run — nothing written)")
        return 0

    async with SessionLocal() as session:
        # Idempotency: skip rows whose (name, directory) already exists.
        existing = (
            await session.execute(select(Listing.name, Listing.directories))
        ).all()
        keys = {(name, tuple(dirs or [])) for name, dirs in existing}
        skipped = 0
        for listing in listings:
            key = (listing.name, tuple(listing.directories))
            if key in keys:
                skipped += 1
                continue
            session.add(listing)
        await session.commit()
        print(f"Wrote {len(listings) - skipped} listings ({skipped} skipped as duplicates).")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["mock", "sheets"], default="mock")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    return asyncio.run(run(args.source, args.dry_run))


if __name__ == "__main__":
    sys.exit(main())
