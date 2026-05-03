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
| 1. Foundation (this scaffold) | ⏳ in progress |
| 2. Directories & content (other 9 dirs, Events, search, v1 migration) | not started |
| 3. Monetization (paid listings, invoices, push) | not started |
| 4. Launch (TestFlight, App Store, v1 sunset) | not started |

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
