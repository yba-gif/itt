# ITT-Rehber 2.0

Native iOS directory app for the Turkish community in Switzerland — full rebuild of v1.

**Status:** Phase 1 (Foundation) scaffold. See `docs/architecture.md` for what's wired up vs deferred.

## Repo layout

```
apps/ios/        SwiftUI app (iOS 16+) — XcodeGen-driven
apps/backend/    FastAPI + Postgres + SQLAlchemy
apps/admin/      React + Vite admin moderation panel
infra/hetzner/   Production docker-compose
scripts/         Seed, v1 migration (skeleton)
docs/            PRD, architecture, API
```

## Local dev quickstart

Requires Docker Desktop, Node 20+, Python 3.11–3.13, Xcode 15+, [XcodeGen](https://github.com/yonki/XcodeGen) (`brew install xcodegen`).

```bash
make verify   # opens Docker Desktop if needed, brings up stack, runs e2e tests
```

Or step-by-step:

```bash
make up         # postgres, minio, backend (:8000), admin (:5173) — auto-launches Docker Desktop
make health     # curl /healthz
make test       # full pytest suite against the running stack
make ios        # xcodegen + open Xcode project
make admin      # npm install + Vite dev server (host-side, no Docker)
make down       # stop the stack
```

**Seeded admin login:** `bek@itt-rehber.ch` / `changeme` (set via `ADMIN_SEED_PASSWORD`).

### Troubleshooting

- **`docker: command not found`** — Docker Desktop's symlink at `/usr/local/bin/docker` is stale on machines that did the legacy DMG install. The Makefile resolves this by calling `/Applications/Docker.app/Contents/Resources/bin/docker` directly, and runs `open -a Docker` to start the daemon if it's not running.
- **`pytest: command not found`** — `make test` creates a venv at `apps/backend/.venv` and uses it. To run pytest manually: `source apps/backend/.venv/bin/activate`.
- **Python version** — Defaults to `python3.13`. Override with `make test PY=python3.12` if needed. Python 3.14 is bleeding-edge; some wheels may not be ready yet.

## Phase 1 acceptance loop

End-to-end submit → moderate → display for the **Sağlık** directory:

1. iOS app: Profil → email signup → Rehber → Sağlık → Hizmetinizi Ekleyin → submit.
2. Admin panel: log in → Queue → see pending listing → Approve.
3. iOS app: pull-to-refresh on Sağlık list → listing appears.

## Phase status

| Phase | Status |
|---|---|
| 1. Foundation (auth, Sağlık E2E, admin queue, offline cache) | ✅ done |
| 2. Directories & content (10 dirs, Events, FTS search, CMS, favorites, saved searches, v1 migration, claim) | ✅ done |
| 3. Monetization (paid listings, PDF invoices, TWINT QR, payment recon, push, image uploads, expiry) | ✅ done |
| 4. Launch (TestFlight, App Store, v1 sunset) | not started |

**Phase 3 highlights:**
- Paid submission flow: 60/100/180 CHF for 3/6/12 months, first month free, multi-directory + multi-kanton no-extra-cost.
- Server-rendered PDF invoices via reportlab with TWINT QR + bank instructions; sequential `ITT-YYYY-NNNNN` numbering.
- Email service (SMTP via env, logger-only fallback for dev) auto-sends invoice on submit.
- Admin Pending Payment queue with TWINT/Havale alındı buttons; mark-paid extends `paid_until` by package duration.
- `scripts/expire-and-remind.py` runs daily: active→expired, expired→archived (90d), 30-day renewal reminders.
- APNs push: `DeviceToken` model, `/push/register` from iOS, admin push composer with kanton + category targeting.
- Image upload pipeline: `/uploads/image` (multipart), Pillow validation (200×200 min, 5 MB max), EXIF strip, JPEG normalize, R2/MinIO PUT.
- iOS: PhotosPicker + image upload + package picker + post-submit invoice screen + push permission requested contextually after first event view.

**Phase 2 highlights (since v0.1):**
- Backend: 10 directories, real Events feed (PRD §5.3 v1 date-filter bug fixed), Postgres FTS on `tsvector + unaccent`, ContentPage CMS, Favorites, Saved Searches, listing claim flow with email match.
- iOS: 5-tab UI (added Ara), real Events tab with `EventKit` reminders + past sub-tab, global search, Bilgi tab pulls from CMS, favorites toggle, claim banner.
- Admin: Events moderation queue, Markdown content editor.
- Migration: `scripts/migrate-from-v1.py --source=mock` works end-to-end (real Sheets pull deferred to live launch).

## Decision log

See PRD `docs/prd.md` §12 for locked decisions. The most load-bearing for engineering:

- iOS only, Swift/SwiftUI, iOS 16+
- FastAPI + Postgres
- TWINT + bank transfer (no IAP, no in-app payment)
- Manual moderation, no auto-publish
- No anonymous-user analytics
- Turkish UI only at launch

## License

Proprietary. © Roar (Yusuf Berkan Altun). All rights reserved.
