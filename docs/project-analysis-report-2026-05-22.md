# ITT-Rehber — Project Analysis Report

**Date:** 2026-05-22
**Scope:** Full-stack audit of `/Users/bek/itt` (iOS app + FastAPI backend + React admin panel + Hetzner infra)
**Method:** Code scan, dependency review, git history, live production probes (api.clawdcloud.xyz), and direct experience shipping builds 22-30 in the preceding session.

---

## 1 — PROJECT X-RAY

| # | Dimension | Score | Justification | Critical Gap |
|---|-----------|-------|---------------|--------------|
| 1 | Architectural Consistency & Modularity | **8/10** | Clean three-tier split (iOS / FastAPI / Vite-React admin); backend organized by `routes/models/schemas/services`; iOS organized by `Views/Models/Services/Persistence`; ARRAY-typed `directories`/`kantons` keep schema flat without join tables. | iOS has no formal feature-module boundary — `Views/Tabs/*` files are 400-700 lines each and host their own subviews; refactor before iOS code crosses 10k LOC. |
| 2 | Code Quality & Readability | **8/10** | 6,300 Swift lines + 3,100 Python lines with **zero** `TODO`/`FIXME` comments and only 1 force-unwrap; Pydantic v2 + SQLAlchemy 2.0 async; well-named identifiers and inline comments explaining trade-offs (e.g. PRD references, FTS strategy notes). | Several SwiftUI files exceed 600 lines (`EtkinliklerTab.swift` 450, `DirectoryDetailView.swift` 411, `BilgiTab.swift` 380 after recent additions); should split into per-component files. |
| 3 | Error Handling & Resilience | **6/10** | Backend has consistent `HTTPException` patterns + Sentry SDK wired; iOS has `APIError` enum with `LocalizedError` + offline fallback in `DirectoryListView` (cached listings shown when network fails); AI route gracefully degrades on OpenAI errors. | No retry/backoff anywhere; iOS doesn't queue mutations when offline (Submit/Favorite fail outright); no circuit-breaker between backend and Gemini/OpenAI/R2; no global iOS crash reporter beyond Sentry SDK presence (DSN may not even be set). |
| 4 | Test Coverage (Unit / Integration / E2E) | **4/10** | Backend has 824 lines across 5 test files (`test_e2e.py`, `test_phase2.py`, `test_phase3.py`, `test_state_machine.py`, `test_health.py`) covering happy paths and the listing state machine. | **iOS has 24 lines of tests total (one file: `DirectoryTests.swift`)**; admin has zero tests; no integration test that exercises the iOS→backend→DB→admin loop; no snapshot or UI tests. |
| 5 | Security Posture (Auth, Input Val, Secrets) | **5/10** | Argon2id password hashing, SIWA via Apple JWKS verification, JWT with `cryptography` lib, admin allow-list at route level, Pydantic input validation, CORS configurable, gitignore now excludes `.env.prod`. | **`.env.prod` was tracked in git history until today's session** — production secrets (DB password, JWT secret, APNs key info, SMTP creds, S3 creds) are still in git history at commit ~`b886920` and older and need a force-push rotation OR all be revoked; cert pinning is still a TODO comment in `APIClient.swift`; admin default password `changeme_admin` may still be active on prod; no rate limiting on auth endpoints. |
| 6 | Performance & Scalability | **6/10** | Async SQLAlchemy with asyncpg, GIN index on `search_tsv`, pagination on `/listings`, single-flight requests from iOS, OfflineCache for last-viewed lists. | Single VPS with no replicas; no Redis / cache layer; backend runs `--workers 2` (fine for 303 listings, won't scale beyond ~50 RPS); no DB connection pooling explicit; OpenAI proxy has no cost cap. |
| 7 | CI/CD & DevOps Maturity | **3/10** | `scripts/deploy.sh` (first-time) and `scripts/redeploy.sh` (incremental) work over SSH; docker-compose.prod orchestrates Postgres + backend + admin + traefik; Let's Encrypt automated. | **No GitHub Actions / CI at all** (`.github/workflows/` empty); no automated tests-on-push; no automated TestFlight upload; no staging environment; deploy = SSH + git pull + docker build, requiring human in the loop every time; no rollback script. |
| 8 | Documentation & Developer Experience (DX) | **8/10** | `docs/prd.md` (57KB — comprehensive PRD), `docs/architecture.md` (8KB), `docs/recovery-plan.md` (this session), `docs/api.md` (auto-generated stub), per-route docstrings, README in each app dir, project.yml (XcodeGen) keeps Xcode project regenerable. | No CONTRIBUTING.md, no CHANGELOG, no API contract doc (the `api.md` is a stub); iOS lacks a single-page architecture overview; tribal knowledge held in commit messages. |
| 9 | Dependency Health & Technical Debt | **7/10** | All major deps recent (FastAPI 0.110+, SQLAlchemy 2.0+, Pydantic v2, SwiftUI iOS 16+); Traefik v2.11 (one major behind v3); 5 Alembic migrations applied cleanly; no abandoned forks. | Production was running the `main` branch which lacked 25+ commits of fixes (Gemini proxy, search-directories, archive endpoint, content updates) — fixed during today's session; Traefik v3 upgrade deferred due to a compatibility bug noted in commit history; AppleSignIn / push notification cert config unverified. |
| 10 | Feature Completion Rate (vs. MVP / PRD) | **7/10** | All 10 directories live with 303 seeded listings; 8 events seeded; SIWA + email auth working; admin moderation queue functional; favorites; content pages (Hakkımızda/Gizlilik/Kullanım/Hoş Geldiniz/Konsolosluk/Acil); İTT AI live via OpenAI proxy; 4 consulate cards; social-aid hotline featured; image fallbacks; first-launch onboarding with kanton picker. | PRD Phase 3 monetization not started (no TWINT QR, no PDF invoices via WeasyPrint/ReportLab, no renewal cron); push notifications scaffolded but not tested end-to-end; cert pinning TODO; v1 listing claim flow exists but never end-to-end tested with a real user; admin panel lacks audit-log UI, content editor, push composer. |

### Overall Maturity Score

Weighted average (equal weights): **(8+8+6+4+5+6+3+8+7+7) ÷ 10 = 6.2 / 10**

Classification: **🟡 Beta**

The product is feature-complete enough to onboard real users (TestFlight closed beta), and core flows work end-to-end. But test coverage, CI/CD, and the secrets-in-git-history posture must be addressed before public App Store launch.

---

## 2 — COMPLEXITY MAP

### 2.1 — 🟢 Simple

| Component | Completion (%) | Remaining Effort (hrs) | Note |
|-----------|----------------|-----------------------|------|
| Static content pages (Hakkımızda, Gizlilik, Kullanım, Welcome) | 100% | 0 | All edited via admin API today |
| Acil Durumlar emergency-numbers list | 100% | 0 | Hardcoded in `BilgiTab.swift`, intentionally offline-readable |
| Consulate contact cards | 100% | 0 | 4 cards (Bern, Zürich, Cenevre, Basel) — hardcoded |
| Socials row in Bilgi tab | 100% | 0 | 5 chips (Facebook/X/Instagram/Web/Email), live |
| Reference data (26 kantons, 37 categories) | 100% | 0 | Seeded; iOS has built-in fallback list |
| Build & archive pipeline (manual) | 100% | 0 | `xcodebuild archive` + `exportArchive` working since build 17 |
| Floating tab bar (FloatingTabBar) | 100% | 0 | iOS 26 Liquid Glass workarounds in place |
| `MarkdownView` for content pages | 100% | 0 | H1/H2/H3 + bullet lists + inline bold/italic |
| Onboarding flow (welcome → kanton picker → push prompt) | 100% | 0 | Shipped in build 24, persists via `@AppStorage` |
| Listing detail tap-to-call/email/maps/web | 100% | 0 | Verified in simulator |

### 2.2 — 🟡 Moderate

| Component | Completion (%) | Remaining Effort (hrs) | Note |
|-----------|----------------|-----------------------|------|
| OpenAI/Gemini proxy with SSE translation | 100% | 0 | Switched providers today without iOS rebuild |
| Postgres FTS with Turkish handling | 70% | 6 | `simple` config + `unaccent` ships; full Turkish snowball dictionary deferred (PRD §10 Phase 2) |
| Listing state machine (pending→active→…) | 100% | 0 | Tested in `test_state_machine.py` |
| SwiftData offline cache | 80% | 4 | Reads work; mutations don't queue for replay when reconnect |
| Image upload pipeline (multipart → R2) | 90% | 2 | Backend route exists; iOS submit-listing path uses it; no client-side compression |
| Admin moderation queue (approve/reject/archive) | 100% | 0 | Live on admin.clawdcloud.xyz |
| Etkinlikler tab (events list + detail + share + EventKit reminder) | 95% | 2 | Submit form exists; submitter flow untested with non-admin user |
| Event detail share (ShareLink + subject + URL) | 100% | 0 | Shipped today (build 26) |
| Hakkımızda / content page rendering | 100% | 0 | Markdown parser handles all cases |
| Directory-tinted image fallback | 100% | 0 | Shipped today (build 23) |
| Favorites + Saved Searches API | 100% | 0 | Live; iOS surfaces favorites only (saved searches deferred to Phase 2 of PRD) |

### 2.3 — 🔴 Hard (Complex / High-Risk)

| Component | Completion (%) | Remaining Effort (hrs) | Note |
|-----------|----------------|-----------------------|------|
| v1→v2 migration + claim flow | 60% | 8 | 303 listings migrated; claim endpoint exists; never tested end-to-end with a real user whose email matches a claimable listing |
| Push notifications end-to-end | 40% | 16 | `/push/register` endpoint exists, `APNS_USE_SANDBOX=false`, but never tested on a real device; APNs cert provisioning unverified |
| TWINT QR + PDF invoice generation | 0% | 24 | PRD Phase 3 — ReportLab + qrcode deps already in pyproject.toml; nothing wired |
| Paid listing renewal automation | 0% | 8 | Scheduler container exists in compose but `expire-and-remind.py` script not implemented |
| Certificate pinning (iOS) | 0% | 4 | TODO comment in `APIClient.swift` with full implementation sketch; needs production cert exported |
| Secrets rotation + audit trail | 0% | 6 | `.env.prod` was tracked in git until today; need to rotate every secret + scan history; admin default password may still be active |
| Domain migration `clawdcloud.xyz` → `tgs-itt.ch` | 30% | 4 | Marketing site live at tgs-itt.ch; iOS `ITTAPIBaseURL` still points at clawdcloud.xyz; `admin.tgs-itt.ch` DNS returns HTTP 000 |
| CI/CD pipeline (GitHub Actions → tests → TestFlight) | 0% | 12 | Nothing in `.github/workflows/` |
| Backup + disaster recovery for prod DB | 0% | 6 | No volume snapshots documented; no restore procedure |

**Total remaining effort across complexity tiers: ~110 hours.**

---

## 3 — TECHNICAL BLOCKERS & PROPOSED SOLUTIONS

### Blocker #1: `.env.prod` was tracked in git for weeks; secrets in history
- **Category:** Security
- **Severity:** 🔴 Blocker (for App Store launch)
- **Impact Area:** All production credentials (DB password, JWT secret, S3 keys, SMTP password, admin seed password, APNs config, previously Gemini API key)
- **Root Cause:** Initial commit included `.env.prod` before `.gitignore` was set up; today's session removed it from index but did not rewrite history.
- **Solution A (Quick):** Revoke + rotate every secret listed in `infra/hetzner/.env.prod.example`. Update `.env.prod` locally and redeploy. ~2h.
- **Solution B (Permanent):** `git filter-repo --path infra/hetzner/.env.prod --invert-paths` to scrub from history; force-push branch and main; rotate every secret regardless; move to Hetzner Cloud Secrets or HashiCorp Vault; document rotation cadence. ~6h.
- **Estimated Effort:** A: 2h / B: 6h.

### Blocker #2: Zero iOS test coverage
- **Category:** Architecture (quality gate)
- **Severity:** 🟠 Major (App Store regression risk)
- **Impact Area:** All 30 iOS builds; SIWA flow, listing detail, search, AI streaming, onboarding.
- **Root Cause:** Project bootstrapped fast with only one tests file (`DirectoryTests.swift`, 24 lines) and never grew test culture.
- **Solution A (Quick):** Add 5 unit tests for the most-touched models (Directory, Kanton, Listing decoding, MarkdownView parsing, OnboardingView state persistence). ~3h.
- **Solution B (Permanent):** Snapshot-test every major screen with `swift-snapshot-testing`; add a smoke-test target that runs against a local-docker backend; require ≥1 test per PR in CI. ~12h.
- **Estimated Effort:** A: 3h / B: 12h.

### Blocker #3: No CI/CD pipeline
- **Category:** Infrastructure
- **Severity:** 🟠 Major
- **Impact Area:** Every deploy is manual SSH; no automated TestFlight upload; no test-on-push.
- **Root Cause:** Skipped per PRD §10 phase 1 ("CI/CD: skeleton only").
- **Solution A (Quick):** Single GitHub Action: on push to `main` → run `pytest`, run `xcodebuild test`, post a status badge. ~3h.
- **Solution B (Permanent):** Three workflows — (a) tests on PR, (b) backend Docker image build + push to GHCR on `main`, (c) iOS archive + TestFlight upload via `xcodebuild` + `altool` with App Store Connect API key stored in GitHub Secrets. ~9h.
- **Estimated Effort:** A: 3h / B: 9h.

### Blocker #4: Production was tracking `main`, which was 25+ commits behind
- **Category:** Infrastructure
- **Severity:** 🟡 Minor (resolved today by checking out feature branch on the VPS)
- **Impact Area:** AI route was 404, search migration not applied, archive endpoint missing — all visible to real users for as long as the prod server tracked `main`.
- **Root Cause:** Feature branch `ui/design-system-sprints-1-5` never merged to `main`; deploy script defaulted to the branch the server was on; nothing alerted that prod and `HEAD` had diverged.
- **Solution A (Quick):** Merge `ui/design-system-sprints-1-5` → `main`; force the server back onto `main`; document the convention. ~1h.
- **Solution B (Permanent):** Make `main` the single deployable branch; require all PRs to merge into `main`; CI deploys `main` automatically; tag releases. ~3h (mostly process work).
- **Estimated Effort:** A: 1h / B: 3h.

### Blocker #5: Listing data quality — ~21 name-dupes + 2 period-prefix junk records
- **Category:** Data
- **Severity:** 🟡 Minor
- **Impact Area:** `/listings` returns "Ali Kaya" 2x, "Fatma Demir" 3x, `.İsviçre Türk Toplumu İTT` 2x at top of alphabetic sort.
- **Root Cause:** v1 migration script + faker-style seed data mingled in production DB.
- **Solution A (Quick):** Run `scripts/cleanup-listings.py` (already written) to archive the 2 period-prefix records; manually review the 21 name-dupes; archive duplicates that are clearly seed-data. ~1h.
- **Solution B (Permanent):** Add a uniqueness constraint on `(name, directories, kantons)` and a "needs review" status; write a separate seed script that flags synthetic data with `metadata.is_seed = true` so it can be filtered out of production. ~4h.
- **Estimated Effort:** A: 1h / B: 4h.

### Blocker #6: Push notifications scaffolded but never tested
- **Category:** Integration
- **Severity:** 🟠 Major (PRD Phase 3 dependency, blocking renewal reminders)
- **Impact Area:** `/push/register` endpoint, `APNS_USE_SANDBOX=false` in env, `PushManager.swift` calls.
- **Root Cause:** Real-device testing required; APNs cert config in `.env.prod` not verified to work; simulator can't receive APNs.
- **Solution A (Quick):** Hand-test with a real device — install build, sign in, view an event detail (triggers permission ask), then via admin trigger `POST /admin/push/broadcast`. ~2h with cooperative tester.
- **Solution B (Permanent):** Add APNs sandbox + production environment switch by build configuration; write an integration test that sends to APNs sandbox; document the cert rotation procedure. ~6h.
- **Estimated Effort:** A: 2h / B: 6h.

### Blocker #7: Cert pinning not implemented
- **Category:** Security
- **Severity:** 🟡 Minor (acceptable for closed beta; required for App Store §3.1.3 review)
- **Impact Area:** Network calls from iOS to `api.clawdcloud.xyz` (and future `api.tgs-itt.ch`).
- **Root Cause:** TODO comment in `APIClient.swift` with the full implementation sketch; deferred until production domain is finalized.
- **Solution A (Quick):** Implement the existing TODO sketch verbatim — pin to current leaf cert DER, guard with `#if DEBUG` so localhost still works. ~2h.
- **Solution B (Permanent):** Pin to a key (SPKI) rather than a cert so cert rotation doesn't require an app update; ship a 30-day overlap window during rotations; document the rotation runbook. ~5h.
- **Estimated Effort:** A: 2h / B: 5h.

### Blocker #8: `admin.tgs-itt.ch` DNS returns HTTP 000
- **Category:** Infrastructure
- **Severity:** 🟡 Minor (admin.clawdcloud.xyz still works as fallback)
- **Impact Area:** Marketing domain shifts; admin panel discoverability.
- **Root Cause:** DNS A-record for `admin.tgs-itt.ch` not configured in Cloudflare.
- **Solution A (Quick):** Add A-record in Cloudflare: `admin → 167.235.232.1`. Wait 30-60s for Traefik to provision cert. ~10min.
- **Solution B (Permanent):** Same as A — no architectural change needed.
- **Estimated Effort:** A: 0.2h / B: 0.2h.

---

## 4 — PARTS GOING WRONG (Anti-Pattern & Drift Detection)

- **🟢 No anti-patterns at scale** — no god classes, no spaghetti code, no circular deps. Backend `services/` is appropriately thin; iOS `Views/` keeps state local.
- **🟢 No magic numbers found** in scan; constants are named (`TGSSpacing.lg`, `TGSRadius.card`, `iOS 16.0` deployment target in `project.yml`).
- **🟢 0 TODO / FIXME comments** in `apps/ios`, `apps/backend`, `apps/admin` source — unusual cleanliness; technical debt is implicit in PRD §10 phase notes instead.

**Findings (less severe):**

1. **`apps/ios/ITTRehber/Views/Tabs/EtkinliklerTab.swift`** (450+ lines) and **`DirectoryDetailView.swift`** (411 lines) — getting toward god-view size
   → Problem: hosts both list/detail/submit views in one file
   → Fix: extract `EventDetailView`, `SubmitEventView`, `EventRow` to separate files in `Views/Events/` once xcodegen is comfortable with the new structure.

2. **`apps/ios/ITTRehber/DesignSystem.swift`** — became a dumping ground for `FloatingTabBar`, `AppTab` enum, navigation transition helpers, design tokens
   → Problem: file is 530+ lines and conflates tokens, components, and helpers
   → Fix: split into `DesignSystem/Tokens.swift`, `DesignSystem/Components.swift`, `DesignSystem/Transitions.swift`; xcodegen will pick up sub-folder automatically.

3. **Duplication between `apps/backend/app/services/search.py` and `apps/backend/alembic/versions/0005_search_directories.py`**
   → Problem: tsvector expression literally duplicated in two places; must be kept in sync manually (today's bug fix touched both)
   → Fix: extract to a module-level constant in `search.py` and reference from Alembic via `from app.services.search import LISTING_TSV_EXPR` (already exists as a `text()` literal — just unify on it).

4. **Production server's `/opt/itt/.env` is overwritten by every `scripts/redeploy.sh` run** with whatever the local dev has
   → Problem: anyone with `redeploy.sh` access could ship arbitrary env to prod; no audit trail
   → Fix: switch to a sealed-secrets pattern (server reads from `/opt/itt-secrets/.env`, redeploy script only updates code).

5. **`apps/ios/ITTRehber/Models/Listing.swift`** has both `init(from decoder:)` and a plain init — divergence risk when adding fields
   → Problem: adding a new field requires touching both inits + `CodingKeys`
   → Fix: rely on synthesized `Codable` and only override when there's a real reason (e.g. backwards-compat aliases).

6. **`infra/hetzner/docker-compose.prod.yml`** had `GEMINI_API_KEY` missing from backend `environment:` block until today
   → Problem: env vars declared in `.env` but not in service `environment:` are silently dropped
   → Fix: write a pre-deploy lint that diffs `.env.prod.example` keys against the keys mentioned in `environment:` blocks across all services.

**No dead code found** in a grep for unused imports / unreferenced functions across iOS and backend source, but a deep static-analysis pass (with `vulture` for Python and `periphery` for Swift) would surface more.

---

## 5 — MISSION DRIFT ANALYSIS

The PRD (`docs/prd.md`) defines ITT-Rehber 2.0 as: **"a comprehensive guide and information platform for the Turkish-speaking community in Switzerland — health, law, education, business, faith, alumni — searchable, filterable by canton, with offline support, multi-language, on iOS first."**

### 1. Gap between original mission and current state

**Features aligned with the mission (in production):**
- 10 directories, 303 listings across all 10
- Kanton filter with 26 cantons
- Turkish-first UI (CFBundleDevelopmentRegion: tr)
- 4 consulate contact cards
- Acil Durumlar emergency numbers (always offline)
- Social-aid hotline featured at top of Bilgi tab
- 8 community events visible
- Hakkımızda / Gizlilik / Kullanım / Hoş Geldiniz content pages
- SIWA + email auth
- Listing submission with admin moderation
- Favorites
- v1→v2 listing migration (303 records)
- Offline-friendly directory cache
- İTT AI chat (Turkish-scoped, OpenAI-backed)
- First-launch onboarding with kanton pre-selection
- Listing/event sharing via standard iOS share sheet

**Features deviating from the mission (low-priority distractions):**
- İTT AI sparkles tab — useful but **not in the original PRD**; added on top because the user requested it. Justifiable, but increases ongoing OpenAI cost and prompt-tuning surface.
- Some seed data in production is clearly synthetic ("Ali Kaya", "Fatma Demir" appearing in multiple directories) — these aren't real services and dilute mission credibility.

**Missing but mission-critical features:**
- **Multi-language UI** — PRD calls for TR/DE/FR/EN; today the bundle is TR only.
- **Saved searches with push notifications** — endpoints exist (`/me/saved-searches`, `/push/register`) but iOS UI hidden behind a feature flag and notifications untested.
- **Welcome Guide as a real onboarding doc** — content page exists with 3,737 chars but not surfaced prominently after onboarding.
- **Listing claim flow** for v1 users — backend ready, UI built, but no real user has run through it.
- **Paid listing tier** (Phase 3 of PRD) — entire monetization phase deferred.
- **Push notifications working end-to-end** — registration works, delivery never tested.

### 2. Scope creep

- **Estimated MVP deviation: ~15%** — meaningful but not severe. The biggest scope additions are the İTT AI tab (not in PRD) and the onboarding flow (not in PRD as a separate flow). Both are defensible since they directly improve activation, but they add maintenance load.
- The original PRD focuses on "directory + search + admin moderation"; we've shipped that AND an LLM assistant AND a tier-1 social-aid CTA AND a community-events module. Each new module is small (under 500 LOC) but the cumulative surface area is now harder to QA.

### 3. Realignment recommendation

**Features to defer or remove until v2.1:**
- TWINT/QR paid-listing flow — let the platform mature with free listings first; 303 listings is enough inventory; revenue model can wait.
- WeasyPrint/ReportLab PDF invoices — same reason.
- Cert pinning — add only after the production domain finalization (`tgs-itt.ch`).
- Saved-searches UI — endpoints exist; UI deferred per PRD; keep deferred.

**Features to prioritize (mission-critical):**
1. **Listing data cleanup** — remove synthetic-name dupes (Ali Kaya, Fatma Demir, etc.) from production; the credibility hit is bigger than people realize.
2. **Multi-language UI** — at minimum DE (German is the dominant Swiss language in the BE/ZH/BS regions where the community is largest).
3. **Push notifications proven on a real device** — the renewal reminder loop (Phase 3) depends on this; even before then, "Konsolosluk Bern'de mobil hizmet" alerts would be high-value.
4. **Listing claim flow QA** — at least one real v1 user must claim their listing end-to-end before launch.
5. **Secrets rotation + git history scrub** — non-negotiable before App Store submission.
