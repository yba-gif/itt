#!/usr/bin/env python3
"""Seed 8 realistic upcoming events for the Turkish-Swiss community.

Phase 1.3 of the recovery plan (docs/recovery-plan.md).

Each event is submitted then admin-approved so it appears on /events
immediately. Events span Zürich, Bern, Genf, Basel — the main cantons
with active Turkish communities.

Usage:
    export ITT_ADMIN_PW='changeme_admin'
    python3 scripts/seed-events.py [--dry-run]
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

BASE = "https://api.clawdcloud.xyz"
ADMIN_EMAIL = "bek@itt-rehber.ch"
DRY_RUN = "--dry-run" in sys.argv

# Reference "now" for relative event dates
NOW = datetime.now(timezone.utc).replace(microsecond=0)


def at(days: int, hour: int, minute: int = 0) -> str:
    """ISO timestamp `days` from now at given time (UTC)."""
    return (NOW + timedelta(days=days)).replace(hour=hour, minute=minute, second=0).isoformat()


# 8 realistic events spanning ~8 weeks
EVENTS = [
    {
        "title": "TGS-ITT Geleneksel Kermes — Zürich",
        "description": (
            "Yıllık bahar kermesimize tüm Türk topluluğu davetlidir. "
            "Türk mutfağı, el işi sergisi, çocuklar için oyun alanı ve canlı müzik. "
            "Gelirin tamamı TGS-ITT öğrenci bursları için kullanılacaktır."
        ),
        "starts_at": at(5, 11),
        "ends_at": at(5, 18),
        "kanton": "ZH",
        "venue": "Schweizerische Volksschule Zürich",
        "address": "Stadelhoferplatz 8, 8001 Zürich",
    },
    {
        "title": "Almanca Konuşma Kulübü — Bern",
        "description": (
            "B1/B2 seviyesi Almanca konuşma pratiği. Türkçe destekli, ücretsiz. "
            "Her hafta farklı tema. Bu hafta: Vergi beyannamesi terminolojisi."
        ),
        "starts_at": at(10, 18, 30),
        "ends_at": at(10, 20, 30),
        "kanton": "BE",
        "venue": "TGS-ITT Bern Kültür Merkezi",
        "address": "Effingerstrasse 19, 3008 Bern",
    },
    {
        "title": "Konsolosluk Mobil Hizmet — Basel",
        "description": (
            "Cenevre Başkonsolosluğu Basel'de mobil hizmet verecek. "
            "Pasaport, nüfus, kimlik işlemleri için ön randevu zorunludur. "
            "Randevu: konsolosluk web sitesi."
        ),
        "starts_at": at(14, 9),
        "ends_at": at(14, 17),
        "kanton": "BS",
        "venue": "Basel Türk Toplumu",
        "address": "Wallstrasse 11, 4051 Basel",
    },
    {
        "title": "Çocuklara Türkçe Atölyesi (5–10 yaş)",
        "description": (
            "İsviçre'de büyüyen çocuklarımıza Türkçe okuma-yazma atölyesi. "
            "Hikaye, oyun ve resim ile öğrenme. Aylık seri — kayıt gerekli."
        ),
        "starts_at": at(17, 14),
        "ends_at": at(17, 16),
        "kanton": "ZH",
        "venue": "TGS-ITT Zürich Eğitim Merkezi",
        "address": "Hardstrasse 219, 8005 Zürich",
    },
    {
        "title": "İsviçre'de Şirket Kurma Semineri — Cenevre",
        "description": (
            "GmbH ve Einzelfirma kurma adımları, vergi yapısı, AHV/AVS yükümlülükleri. "
            "Türkçe konuşan mali müşavir Cenevre'de soru-cevap formatında. Ücretsiz."
        ),
        "starts_at": at(21, 18),
        "ends_at": at(21, 20, 30),
        "kanton": "GE",
        "venue": "TGS-ITT Genève",
        "address": "Avenue Soret 4, 1203 Genève",
    },
    {
        "title": "Anneler Günü Brunch'ı — Luzern",
        "description": (
            "Geleneksel Türk kahvaltısı eşliğinde Anneler Günü kutlaması. "
            "Müzik, şiir dinletisi ve hediyeler. Tüm aileler davetlidir."
        ),
        "starts_at": at(28, 10),
        "ends_at": at(28, 14),
        "kanton": "LU",
        "venue": "Hotel Schweizerhof Konferans Salonu",
        "address": "Schweizerhofquai 3, 6002 Luzern",
    },
    {
        "title": "Mezunlar Buluşması — TGS-ITT Alumni Networking",
        "description": (
            "İsviçre'de okumuş veya çalışmış Türk profesyoneller için ağ kurma akşamı. "
            "Kısa panel: 'İsviçre iş kültüründe Türk profesyonellerin yeri'. "
            "Ardından serbest sohbet ve kokteyl."
        ),
        "starts_at": at(35, 19),
        "ends_at": at(35, 22),
        "kanton": "ZH",
        "venue": "Kongresshaus Zürich",
        "address": "Gotthardstrasse 5, 8002 Zürich",
    },
    {
        "title": "Bayram Sabah Namazı ve Kahvaltı — Lozan",
        "description": (
            "Ramazan Bayramı sabah namazını topluca eda edip, ardından geleneksel "
            "bayram kahvaltısında bir araya geleceğiz. Tüm aileler davetlidir."
        ),
        "starts_at": at(45, 6, 30),
        "ends_at": at(45, 11),
        "kanton": "VD",
        "venue": "Lozan Türk Camii",
        "address": "Avenue de Morges 92, 1004 Lausanne",
    },
]


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
        return {"_error": e.code, "_detail": e.read().decode(errors="replace")[:300]}


def main() -> int:
    pw = os.environ.get("ITT_ADMIN_PW")
    if not pw:
        print("Set ITT_ADMIN_PW environment variable")
        return 2

    if DRY_RUN:
        print("DRY RUN — printing events, no API calls:\n")
        for e in EVENTS:
            print(f"  📅 {e['title']}")
            print(f"     {e['starts_at']}  {e['kanton']}  {e['venue']}")
            print(f"     {e['description'][:80]}…")
            print()
        return 0

    print("==> Logging in as admin…")
    res = http("POST", "/auth/email/login", body={"email": ADMIN_EMAIL, "password": pw})
    if "_error" in res:
        print(f"Login failed: {res}")
        return 1
    token = res["access_token"]
    print("    OK")

    created = 0
    approved = 0
    for e in EVENTS:
        print(f"\n📅 {e['title']}")
        print(f"    Submitting…", end=" ")
        res = http("POST", "/events", token=token, body=e)
        if "_error" in res:
            print(f"❌ {res['_error']} {res.get('_detail','')[:80]}")
            continue
        ev_id = res["id"]
        created += 1
        print(f"✅ id={ev_id[:8]}")

        print(f"    Approving…", end=" ")
        res = http("POST", f"/admin/events/{ev_id}/approve", token=token)
        if "_error" in res:
            print(f"❌ {res['_error']} {res.get('_detail','')[:80]}")
            continue
        approved += 1
        print(f"✅ status={res.get('status')}")

    print(f"\n==> Done. Created {created} events, approved {approved}.")
    print(f"    Verify: curl -s {BASE}/events | python3 -m json.tool")
    return 0 if approved == len(EVENTS) else 1


if __name__ == "__main__":
    sys.exit(main())
