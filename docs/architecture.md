# Architecture (Phase 1 + 2)

This is what the scaffold actually does, what's stubbed, and what's deferred. The PRD (`docs/prd.md`) is the source of truth for product decisions; this document is the source of truth for engineering choices.

## High-level

```
┌─────────────────┐         ┌────────────────────┐
│  iOS app        │  HTTPS  │  Backend           │
│  (SwiftUI)      │ ──────▶ │  FastAPI + Postgres│
└─────────────────┘         │  + Cloudflare R2   │
                            └────────────────────┘
                                 ▲
┌─────────────────┐              │
│  Admin panel    │ ─────────────┘
│  (React/Vite)   │
└─────────────────┘
```

## Components

### Backend (`apps/backend`)

- **Stack:** FastAPI 0.110+, Python 3.11+, SQLAlchemy 2.0 async, Alembic, asyncpg.
- **Auth:** Sign in with Apple (`POST /auth/siwa`, JWKS verified against `https://appleid.apple.com/auth/keys`) **or** email/password (Argon2id, no email verification per PRD §5.6). Server issues HS256 JWTs with 30-day TTL.
- **Listings:** anonymous-readable (`GET /listings`); auth-required to create/edit; admin-required to approve/reject. Status transitions enforced server-side via `Listing.transition_to()` (PRD §6.3).
- **Reference data:** `Kanton` (26 cantons) and `Category` seeded by `app.seed.run` on every boot (idempotent).
- **Search:** Phase 2 ships Postgres FTS — a generated `search_tsv tsvector` column on `listings` populated by trigger from `name + category + sub_category + description + array_to_string(kantons)`, GIN-indexed. Configuration is `simple + unaccent` so unaccented input ("saglik") matches accented stored data ("Sağlık") and vice versa. ILIKE is OR'd in as a fallback so the user can also do partial substring queries that aren't lexeme-aligned. Turkish snowball stemming (e.g., reducing "doktorlar" → "doktor") is a research item for Phase 3.
- **Object storage:** S3-compatible. MinIO in dev (`docker-compose.yml`), Cloudflare R2 in prod. Presigned PUT URL helper exists; image upload endpoint is wired in Phase 2 alongside server-side validation (file type, dimensions, EXIF strip).
- **PII / GDPR:** account deletion (`DELETE /auth/me`) anonymizes active paid listings (`owner_id = NULL`) and hard-deletes pending submissions. Audit logging is via standard request logs in Phase 1.
- **Sentry:** initialized when `SENTRY_DSN` is set; skipped otherwise.

### iOS (`apps/ios`)

- **Stack:** SwiftUI, iOS 16+, NavigationStack, native TabView. XcodeGen for project generation (so the repo doesn't carry a `.pbxproj`).
- **Auth:** email/password wired end-to-end; SIWA button is a placeholder until a real Apple Developer Team is configured.
- **Phase 1 scope:** Sağlık directory (list + detail + submission flow); other 9 directories show "Yakında" placeholder; Etkinlikler tab is a placeholder; Bilgi tab has hardcoded Acil Durumlar (always offline) plus stubs.
- **Offline:** JSON-on-disk cache (`OfflineCache.swift`). Last-viewed Sağlık list is cached and replayed with an "Çevrimdışı veri gösteriliyor" banner if the network is down. Phase 2 will replace this with SwiftData.
- **Maps:** Apple Maps via `MKMapItem`/`CLGeocoder` (PRD §5.2 — falls back to URL if geocoding fails).
- **Localization:** all user-visible strings are Turkish. Localizable.strings has the keys that we plan to externalize; views inline most strings in Phase 1.
- **Bundle ID:** `ch.itt-rehber.app`.

### Admin (`apps/admin`)

- **Stack:** React 18 + Vite + TypeScript + Tailwind + react-router + @tanstack/react-query.
- **Scope:** Login, Listings queue (filterable by status), ListingDetail (Approve / Reject with reason codes per PRD §5.8), Events moderation queue, Markdown content editor for ContentPages.
- **Auth:** email/password admin allow-list, enforced server-side via `is_admin` flag on `User`. SIWA-on-web is Phase 3+.
- **Deferred (Phase 3):** bulk approve, push composer, payment reconciliation, audit log UI, image upload pipeline UI.

## Data model highlights

- `Listing.directories` and `Listing.kantons` are Postgres `ARRAY(TEXT)` (PRD §6.2 — single listing covers multiple directories and kantons at no extra cost). GIN-indexed for `directories.any(...)` queries.
- `Listing.status` is a Postgres ENUM. Allowed transitions live in `ALLOWED_TRANSITIONS` in `models/listing.py`.
- `Listing.owner_id` nullable to support v1-imported listings without owners (PRD §6.4) and account-deletion anonymization (PRD §5.6).

## Decisions log (engineering, not duplicated from PRD §12)

| Decision | Choice | Why |
|---|---|---|
| Hosting | Hetzner Cloud + docker-compose | Cheap, EU-resident, easy lift-and-shift. Swappable later. |
| Object storage | Cloudflare R2 | S3-compatible, EU-resident, cheaper egress than S3. |
| Marketing site | Cloudflare Pages | Free tier, fast CDN, custom domain — fits the zero-fixed-cost goal. |
| iOS project files | XcodeGen | Don't track `.pbxproj` (merge conflicts, churn); declarative spec instead. |
| iOS persistence | JSON-on-disk | SwiftData adds complexity without value at Phase 1 list size. Swap in Phase 2. |
| Backend FTS | Phase 1: ILIKE; Phase 2: Postgres FTS + unaccent (+ Turkish later) | Turkish dictionary tuning is a research task; ILIKE is sufficient for <5k rows. |
| Backend tests | pure-Python state-machine tests always run; API tests gated on `DATABASE_URL` | Lets developers run `pytest` without Docker; full E2E runs against the compose stack. |
| Admin auth | Phase 1: email/password only | SIWA-on-web requires extra Apple config; not blocking moderation. |

## Things that will bite us if not noted

- **DEVELOPMENT_TEAM is empty in `apps/ios/project.yml`** — Xcode will refuse to sign for a real device. Set this before building for hardware. Simulator builds are fine.
- **APP_SECRET in `.env.example` is not safe for prod.** Generate ≥32 bytes random before deploying.
- **No certificate pinning yet.** APIClient has a TODO; wire pinning in Phase 4 when the prod cert is fixed.
- **`requirements()` validators** — none yet; relying on Pydantic v2 `Field(min_length=...)` constraints. Add image dimension/EXIF validation in Phase 2 alongside the upload endpoint.
- **No automated DB backups.** Hetzner README mentions a `pg_dump` cron — wire it before launch.

## Open questions deferred to engineering team

(See PRD §11.2.)

- **Q1 Hosting:** Hetzner picked as Phase 1 default. Revisit if an Oracle Cloud free-tier or Fly.io option shows up.
- **Q2 Image processing pipeline:** Cloudflare Image Resizing is the most likely win — defer to Phase 2 when uploads ship.
- **Q3 Push fanout strategy:** Phase 3 — APNs HTTP/2 with token-based auth and per-kanton iteration; SLO target = first push within 30s of admin click.
- **Q4 Backup cadence + restore drill:** Daily `pg_dump` to Hetzner Storage Box; quarterly restore drill to a scratch VPS. Wire in Phase 4.
- **Q5 Multi-environment:** Phase 4 — staging via a second cheap VPS sharing the same compose file with a different `.env`.
