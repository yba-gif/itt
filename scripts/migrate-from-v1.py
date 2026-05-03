#!/usr/bin/env python3
"""v1 → v2 migration script.

PHASE 1 SKELETON — fields out, mapping out, no live import. Wired and run in Phase 2.

PRD §6.4:
- v1 lives in Google Sheet 1cVUyaR2kpoYNAv1RCUt4XOIvNeIl03st8P9hd4OdAC4
- Tabs to import: etkinlikler, sağlık, hukuk, işletme, finans, tercüme, meslek,
  mezunlar, okullar, camiler_itdv, DestekDers
- Listings imported with status=active, paid_until=launch_date + 1 month, owner_id=NULL
- Validation errors surfaced for manual cleanup before flipping the live switch
- Original "_old" tabs preserved in source but not imported
"""

from __future__ import annotations

import sys
from typing import Any


SHEET_ID = "1cVUyaR2kpoYNAv1RCUt4XOIvNeIl03st8P9hd4OdAC4"

TAB_TO_DIRECTORY: dict[str, str] = {
    "sağlık": "saglik",
    "hukuk": "hukuk",
    "işletme": "isletme",
    "finans": "finans",
    "tercüme": "tercume",
    "meslek": "meslek",
    "mezunlar": "mezunlar",
    "okullar": "okullar",
    "camiler_itdv": "camiler",
    "DestekDers": "destek_dersi",
    "etkinlikler": "_events",  # special-cased below
}


def fetch_sheet_tab(tab_name: str) -> list[dict[str, Any]]:
    """Pull a Google Sheet tab via the public CSV export. Phase 2 will swap to the
    Sheets API with a service-account credential.
    """
    raise NotImplementedError("Phase 2: implement Sheets pull. Skeleton only.")


def map_listing_row(row: dict[str, Any], directory: str) -> dict[str, Any]:
    """Map a v1 row to a v2 Listing payload. Phase 2: write field-level mapping."""
    raise NotImplementedError("Phase 2: implement row mapping with validation errors.")


def map_event_row(row: dict[str, Any]) -> dict[str, Any]:
    """Map etkinlikler row to Event."""
    raise NotImplementedError("Phase 2: implement event mapping.")


def main() -> int:
    print("v1 → v2 migration skeleton. Wire in Phase 2.")
    print(f"Source sheet: {SHEET_ID}")
    print(f"Tabs in scope: {sorted(TAB_TO_DIRECTORY)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
