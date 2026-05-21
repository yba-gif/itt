#!/usr/bin/env python3
"""Clean up dirty listings on production.

Phase 1.2 of the recovery plan (docs/recovery-plan.md).

Action 1 (SAFE — autoexecutes):
    Archive the 2 period-prefix listings named '.İsviçre Türk Toplumu İTT'.
    These are seed-data junk that sort to the top of the alphabetical list.

Action 2 (REVIEW — prints only):
    List all other duplicate-name listings for manual review.
    Many "dupes" are real (e.g. Ali Kaya as both a doctor and a financial advisor
    in different cantons), so we do NOT auto-archive these.

Usage:
    export ITT_ADMIN_PW='changeme_admin'
    python3 scripts/cleanup-listings.py [--dry-run]

Prereq:
    The `/admin/listings/{id}/archive` endpoint must be deployed (it's on
    branch `ui/design-system-sprints-1-5`, commit a1688cb and after).
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from collections import defaultdict

BASE = "https://api.clawdcloud.xyz"
ADMIN_EMAIL = "bek@itt-rehber.ch"

DRY_RUN = "--dry-run" in sys.argv


def http(method: str, path: str, token: str | None = None, body: dict | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{BASE}{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r) if r.length is None or r.length > 0 else {}
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_detail": e.read().decode(errors="replace")[:200]}


def main() -> int:
    pw = os.environ.get("ITT_ADMIN_PW")
    if not pw:
        print("Set ITT_ADMIN_PW environment variable")
        return 2

    print("==> Logging in as admin…")
    res = http("POST", "/auth/email/login", body={"email": ADMIN_EMAIL, "password": pw})
    if "_error" in res:
        print(f"Login failed: {res}")
        return 1
    token = res["access_token"]
    print("    OK")

    # Walk all listings
    print("\n==> Fetching listings…")
    all_items: list[dict] = []
    page = 1
    while True:
        d = http("GET", f"/listings?page={page}&page_size=50")
        items = d.get("items", [])
        if not items:
            break
        all_items.extend(items)
        if len(all_items) >= d.get("total", 0):
            break
        page += 1
    print(f"    {len(all_items)} listings")

    # ----- Action 1: archive period-prefix listings (SAFE) -----
    junk = [i for i in all_items if i["name"].startswith(".")]
    print(f"\n==> Period-prefix junk to archive: {len(junk)}")
    for i in junk:
        print(f"    🚨 {i['id']}  '{i['name']}'  dirs={i.get('directories', [])}")

    if junk and not DRY_RUN:
        print()
        for i in junk:
            print(f"    Archiving {i['id']}…", end=" ")
            res = http("POST", f"/admin/listings/{i['id']}/archive", token=token)
            if "_error" in res:
                print(f"❌ {res['_error']} {res.get('_detail','')[:60]}")
            else:
                print(f"✅ status={res.get('status')}")

    # ----- Action 2: report (don't touch) name dupes for manual review -----
    by_name: dict[str, list[dict]] = defaultdict(list)
    for i in all_items:
        if not i["name"].startswith("."):  # already handled above
            by_name[i["name"]].append(i)
    dupes = {n: rows for n, rows in by_name.items() if len(rows) > 1}

    print(f"\n==> Name-duplicate listings (REVIEW MANUALLY — not auto-archived):")
    print(f"    {len(dupes)} distinct names, {sum(len(r) for r in dupes.values())} total rows\n")
    for n, rows in sorted(dupes.items(), key=lambda x: -len(x[1])):
        print(f"    {len(rows)}x  '{n}'")
        for r in rows:
            print(f"        {r['id']}  dirs={r.get('directories', [])}  kantons={r.get('kantons', [])}")

    print("\nDecide which (if any) of the above are real distinct listings vs. junk")
    print("and archive the junk ones with:")
    print(f"    curl -X POST -H 'Authorization: Bearer <TOKEN>' \\")
    print(f"         {BASE}/admin/listings/<ID>/archive")
    print()
    if DRY_RUN:
        print("DRY RUN — no changes made.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
