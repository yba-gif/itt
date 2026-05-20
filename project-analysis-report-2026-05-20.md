# ITT-Rehber 2.0 — Project X-Ray Report
**Date:** 2026-05-20  
**Scope:** Full codebase audit, Phases 1–3 complete, Phase 4 not started  
**Corpus:** backend 64 files / 4 145 LOC · iOS 23 files / 2 890 LOC · admin 19 files / 937 LOC · tests 824 LOC · 5 git commits

---

## 1. X-Ray Scoring (10 dimensions)

| # | Dimension | Score | Verdict |
|---|-----------|-------|---------|
| 1 | Architecture Clarity | 8 / 10 | Clear 3-tier; minor DRY violations |
| 2 | Code Health | 7 / 10 | Mostly clean; two bad patterns identified |
| 3 | Test Coverage | 6 / 10 | Backend well-tested; frontend zero; script untested |
| 4 | Security Posture | 6 / 10 | Auth solid; 3 hard blockers before prod |
| 5 | Infrastructure Readiness | 5 / 10 | Compose ready; no backup, no CI, no cron |
| 6 | Business Logic Completeness | 7 / 10 | All 3 phases implemented; 2 stubs in money path |
| 7 | Mobile App | 7 / 10 | Solid UX; 1 user-visible data bug; signing blocked |
| 8 | Admin Panel | 7 / 10 | Full workflow; no tests; audit log not surfaced |
| 9 | Data Model | 8 / 10 | PRD-aligned, good indexes, clean state machine |
| 10 | Documentation | 8 / 10 | Honest architecture.md; api.md not yet generated |
| | **Composite** | **6.9 / 10** | |

### Score narratives

**Architecture Clarity (8/10)**  
FastAPI + PostgreSQL + SwiftUI + React admin is a clean, well-understood stack. Domain boundaries are clear: routes own HTTP surface, services own side-effects, models own state. The `_to_public()` projection helper is duplicated across `listings.py` (ln 27) and `search.py` (ln 34) — one change site will drift from the other.

**Code Health (7/10)**  
No God classes, no circular imports found. `listings.py` at 260 lines is the heaviest route file and contains invoice-issuance and email-send logic inline (`create_listing()` lines 130–175) — business logic that belongs in a service. The silent `except Exception: pass` wrapping email send is a hidden failure mode. `APIClient.swift` at 300 lines is growing toward needing decomposition.

**Test Coverage (6/10)**  
824 lines of pytest across 5 files: state machine (67 LOC), health (19), Phase 1 e2e (134), Phase 2 (303), Phase 3 (249). State machine tests are particularly well-designed — pure Python, no DB required. Gaps: zero frontend tests (React admin), `scripts/expire-and-remind.py` tested only via direct DB manipulation in `test_phase3.py` rather than by calling the script itself, `--source=sheets` migration path has no negative-path guard.

**Security Posture (6/10)**  
Strong: Argon2id password hashing, SIWA JWKS remote verification, HS256 JWT 30-day TTL, EXIF strip on image upload, CORS origins allowlist.  
Gaps: no rate limiting on `POST /auth/email/login` (brute-force window), `APP_SECRET` in `.env.example` is only 44 characters of low-entropy ASCII (fine for dev, easy to forget to replace), certificate pinning has a TODO comment in `APIClient.swift` but is not implemented, `DEVELOPMENT_TEAM` is empty in `project.yml` (Xcode refuses to sign for hardware or App Store).

**Infrastructure Readiness (5/10)**  
`infra/hetzner/docker-compose.prod.yml` has Traefik + Let's Encrypt, R2 object storage wiring, and correct restart policies. Critical gaps: `LETSENCRYPT_EMAIL` is consumed by the prod compose but absent from `.env.example`, no `pg_dump` backup cron, `expire-and-remind.py` not scheduled anywhere, no CI/CD pipeline (GitHub Actions skeleton is Phase 4 deferred but nothing exists yet), no Postgres health-check in prod compose (Traefik could route before DB is ready on first boot).

**Business Logic Completeness (7/10)**  
All three payment packages exist, state machine enforces every legal transition, invoice numbering is sequential per year, first-month-free logic is in place, mark-paid extends `paid_until` correctly. Two stubs remain in the money path: `TWINT_PHONE = "+41 79 000 00 00"` and `BANK_IBAN = "CH00 0000 0000 0000 0000 0"` are hardcoded placeholders in `services/invoice.py` — every PDF mailed to a real customer contains wrong payment details. `migrate-from-v1.py --source=sheets` raises `NotImplementedError`.

**Mobile App (7/10)**  
5-tab SwiftUI architecture is clean, Navigation Stack, offline cache, EventKit integration, PhotosPicker + upload, contextual push permission — all implemented. One user-visible data bug: `MyListingsView.loadListings()` calls `APIClient.shared.listings(directory: nil, kanton: nil, query: nil)` which returns the entire public corpus, not the owner's own submissions. SIWA button shows a placeholder `UIAlertController` because no real Apple Developer Team is configured. Certificate pinning TODO comment in `APIClient.swift` remains unimplemented.

**Admin Panel (7/10)**  
Complete moderation workflow: listings queue (filterable by status), listing detail with 6 reason-code reject options, events queue, markdown content editor, payments queue (TWINT/Havale alındı), push composer with live preview. No tests. `payment_method` field in mark-paid form is not validated client-side — any string is accepted. Audit log is backend-logged (standard request logs) but never surfaced in the UI.

**Data Model (8/10)**  
`listings.directories` and `listings.kantons` as `ARRAY(TEXT)` with GIN indexes is the right choice for multi-value filtering without a join table. FTS `tsvector` column populated by trigger, GIN-indexed, `simple + unaccent` configuration handles accented/unaccented Turkish input. Invoice sequential numbering uses per-year prefix correctly. Listing state machine is enforced in a single `transition_to()` method — no scattered status assignments.

**Documentation (8/10)**  
`docs/architecture.md` is unusually honest: the "Things that will bite us" section lists 9 known time-bombs with specific file paths and mitigation notes. `.env.example` is complete and well-commented. `README.md` has a quickstart, troubleshooting, and phase status table. `docs/api.md` is mentioned in the architecture doc as auto-generated by a make target but the file currently does not exist.

---

## 2. Complexity Map

### Hotspots (highest change risk)

| File | LOC | Risk | Why |
|------|-----|------|-----|
| `apps/backend/app/routes/listings.py` | 260 | 🔴 HIGH | create_listing() mixes HTTP, invoice issuance, email dispatch, and flush ordering. Any change to one concern requires reasoning about all three. |
| `apps/backend/app/services/invoice.py` | ~200 | 🔴 HIGH | reportlab layout + TWINT QR generation + pricing logic + sequential numbering all in one file. Hardcoded payment creds make it a prod blocker. |
| `apps/ios/ITTRehber/Services/APIClient.swift` | 300 | 🟡 MED | All API endpoints in one file. Acceptable now (23 endpoints), will need protocol-based decomposition before Phase 4 adds background refresh and notifications. |
| `apps/ios/ITTRehber/Views/Directory/SubmitListingView.swift` | ~280 | 🟡 MED | PhotosPicker + image upload + multi-select kantons + multi-select directories + package picker + API submit. Long view body, tight coupling. |
| `apps/ios/ITTRehber/Views/Tabs/ProfilTab.swift` | ~260 | 🟡 MED | MyListingsView data bug lives here. Favorites, saved searches, claim banner, account deletion — all mixing concerns. |
| `apps/backend/app/seed/run.py` | ~180 | 🟡 MED | Idempotent but sequential — slow on first boot; no async batching. Not a blocker, but will be noticeable on first Hetzner cold-start. |
| `apps/backend/app/routes/events.py` | 125 | 🟢 LOW | Clean, self-contained. |
| `apps/backend/app/routes/moderation.py` | 68 | 🟢 LOW | Thin, straightforward. |
| `apps/backend/app/routes/health.py` | 10 | 🟢 LOW | One function. |
| `scripts/expire-and-remind.py` | ~120 | 🔴 HIGH (ops risk) | Not scheduled. When it runs for the first time on prod with 100+ listings, silent failures (if SMTP is down) will look like success — logging shows 0 emails sent but no error raised. |

### Coupling graph (simplified)

```
create_listing()
    └── issue_invoice()         [services/invoice.py]
        └── next_invoice_number()
        └── render_invoice_pdf()  → reportlab + qrcode
    └── send_email()            [services/email.py]
        └── SMTP or logger fallback
    └── db.flush() × 2          [ordering critical — must happen before email]
```
Any refactor of `create_listing()` must preserve the flush ordering: `listing.id` must exist before `issue_invoice()`, and the commit must precede `send_email()` (best-effort but must happen after data is committed).

---

## 3. Technical Blockers (launch-gate)

### 🔴 CRITICAL — App cannot go to TestFlight/App Store without fixing

| ID | Blocker | Location | Fix |
|----|---------|----------|-----|
| B1 | TWINT_PHONE and BANK_IBAN are placeholder values | `services/invoice.py` lines 30–33 | Replace with real values or move to `settings` (pydantic-settings) so they're injected from env |
| B2 | MyListingsView shows all public listings, not owner's | `ProfilTab.swift` — `loadListings()` | Call `/listings/mine/all` endpoint (which exists and works) — 1-line fix in APIClient + ProfilTab |
| B3 | DEVELOPMENT_TEAM is empty in project.yml | `apps/ios/project.yml` | Must be set to a real Apple Developer Team ID before any device or App Store build |
| B4 | SIWA button shows UIAlertController placeholder | `ProfilTab.swift` + `SIWAButton` | Either wire real SIWA (requires Team ID + entitlement) or remove the button from production UI |

### 🟠 HIGH — Prod deployment will silently fail without fixing

| ID | Blocker | Location | Fix |
|----|---------|----------|-----|
| B5 | expire-and-remind.py not scheduled | `scripts/expire-and-remind.py` | Add cron entry to Hetzner VPS (`0 3 * * * python /app/scripts/expire-and-remind.py`) |
| B6 | SMTP not configured | `.env.example` / prod `.env` | Wire Resend/Mailgun/Postmark relay; set SMTP_HOST, SMTP_USER, SMTP_PASSWORD in prod |
| B7 | APNs not configured | `.env.example` / prod `.env` | Mount .p8 key file, set APNS_KEY_ID and APPLE_TEAM_ID; set APNS_USE_SANDBOX=false for prod |
| B8 | No DB backup | Hetzner VPS | Add `pg_dump | gzip > backup.sql.gz` cron to VPS + off-site copy (Hetzner Storage Box or R2) |
| B9 | LETSENCRYPT_EMAIL missing from .env.example | `.env.example` | Add `LETSENCRYPT_EMAIL=` entry; prod compose will fail Let's Encrypt challenge without it |
| B10 | No rate limiting on auth endpoints | `routes/auth.py` | Add `slowapi` (or nginx `limit_req`) on `POST /auth/email/login` and `/signup`; 5 req/min per IP |

### 🟡 MEDIUM — Blocks live data migration or App Store review

| ID | Blocker | Location | Fix |
|----|---------|----------|-----|
| B11 | `--source=sheets` raises NotImplementedError | `scripts/migrate-from-v1.py` | Implement Google Sheets API connector before v1 sunset |
| B12 | Certificate pinning not implemented | `APIClient.swift` | Wire `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` with pinned cert hash before public launch |
| B13 | payment_method not enum-validated on mark-paid | `admin/src/pages/Payments.tsx` | Constrain to `"twint" | "bank_transfer"` in frontend |
| B14 | docs/api.md does not exist | `docs/` | Run `make docs` (or generate via `openapi.json` dump) — referenced in architecture.md |

---

## 4. Anti-Pattern Detection

### AP1 — `_to_public()` duplicated across route files
**Severity:** 🟡 Medium  
**Files:** `routes/listings.py:27` and `routes/search.py:34`  
Both define an identical `_to_public(listing: Listing) -> ListingPublicOut` function. If `ListingPublicOut` gains a new field (e.g., `rating`, `verified_badge`), the search results will drift from the directory list results silently.  
**Fix:** Extract to `app/schemas/listing.py` as a module-level function; both routes import and call it.

### AP2 — Silent exception swallowing on email send
**Severity:** 🟠 High  
**File:** `routes/listings.py:169`  
```python
try:
    pdf_bytes = render_invoice_pdf(...)
    send_email(...)
except Exception:
    pass  # ← silent
```
In production with SMTP configured, any rendering error (malformed listing name, reportlab crash, SMTP timeout) causes the invoice email to silently not send. The user submits their listing and never receives their invoice PDF. The admin has no visibility that the send failed.  
**Fix:** Replace `pass` with `logger.warning("Invoice email failed for %s: %s", invoice.invoice_number, exc, exc_info=True)`.

### AP3 — Hardcoded payment credentials in source code
**Severity:** 🔴 Critical  
**File:** `services/invoice.py:30–33`  
`TWINT_PHONE`, `BANK_IBAN`, `BANK_NAME`, `PAYEE_NAME`, `PAYEE_ADDRESS` are string constants in the service file. These ship in every container image and are version-controlled. Real bank details should be injected via `settings` (already uses pydantic-settings) so they can be rotated without a code change.  
**Fix:** Add 5 fields to `config.py` with `Optional[str]` types and sane dev defaults; read from `settings.*` in invoice.py.

### AP4 — MyListingsView O(N) public listing fetch
**Severity:** 🔴 Critical (user-visible data bug + perf)  
**File:** `ProfilTab.swift` — `MyListingsView.loadListings()`  
```swift
listings = try await APIClient.shared.listings(directory: nil, kanton: nil, query: nil).items
```
This calls `GET /listings` with no filters and returns ALL active public listings. In Phase 4 with hundreds of listings, this returns every listing in the database to a user who just wants to see their own 1–3 submissions. The dedicated `/listings/mine/all` endpoint exists and works correctly.  
**Fix:** Add `APIClient.myListings() -> [Listing]` calling `GET /listings/mine/all` and call it from `loadListings()`.

### AP5 — Unguarded `NotImplementedError` in migration script
**Severity:** 🟡 Medium  
**File:** `scripts/migrate-from-v1.py`  
The `--source=sheets` path calls a function that unconditionally raises `NotImplementedError`. If a contributor or CI job runs `python migrate-from-v1.py --source=sheets`, it fails with a stack trace that looks like a bug rather than a known stub. There is no test guarding this path.  
**Fix:** Add a `pytest.mark.skip("sheets connector not implemented")` test OR gate the function with a clear `sys.exit("--source=sheets is not yet implemented. See docs/architecture.md #Q-migration.")`.

### AP6 — `LETSENCRYPT_EMAIL` consumed in prod compose but absent from `.env.example`
**Severity:** 🟠 High  
**Files:** `infra/hetzner/docker-compose.prod.yml` uses `${LETSENCRYPT_EMAIL}`; `.env.example` has no entry for it  
First-time deployer will get a silent empty string sent to Let's Encrypt, causing ACME registration to fail.  
**Fix:** Add `LETSENCRYPT_EMAIL=your@email.com` to `.env.example` and to the prod deploy checklist.

---

## 5. Mission Drift Analysis

### PRD compliance

| PRD requirement | Status | Notes |
|-----------------|--------|-------|
| §3.1.3(b) — no in-app payment links | ✅ Compliant | iOS shows only package picker + "instructions by email"; no URLs. Well-documented in architecture.md. |
| §5.2 — Apple Maps fallback | ✅ Compliant | `MKMapItem` + `CLGeocoder`; URL fallback if geocoding fails |
| §5.6 — no email verification on signup | ✅ Compliant | Signup returns token immediately |
| §5.6 — account deletion anonymizes listings | ✅ Compliant | `DELETE /auth/me` sets `owner_id = NULL` on paid listings, hard-deletes pending |
| §5.7 — TWINT + bank transfer | ⚠️ Partial | Implemented but payment details are placeholders |
| §5.8 — 6 rejection reason codes | ✅ Compliant | All 6 codes in admin ListingDetail |
| §5.10 — offline cache | ✅ Compliant | JSON-on-disk with "Çevrimdışı veri" banner |
| §6.3 — listing state machine | ✅ Compliant | `transition_to()` enforced server-side |
| §6.4 — v1 import / claim flow | ⚠️ Partial | Backend + iOS wired; `--source=sheets` not implemented |

### Scope creep vs. planned scope

No unplanned features detected. All Phase 1–3 items map cleanly to PRD sections. Phase 4 (TestFlight, App Store, v1 sunset) is correctly not started.

### Planning drift

| Item | PRD says | Architecture.md says | Reality |
|------|----------|---------------------|---------|
| Turkish FTS stemming | Phase 2 §5.1 | "Phase 3 research item" | `simple + unaccent` shipped; full Turkish dictionary not done — this is a **known, documented** adjustment, not drift |
| SwiftData migration | Phase 2 | "Phase 2 upgrade" | JSON-on-disk still in use — acceptable if Phase 4 is not imminent |
| v1 migration live | Live launch (Phase 4) | Phase 2 / Phase 4 | `--source=sheets` raises NotImplementedError — needs tracking as Phase 4 blocker |
| Payment credential config | N/A (ops concern) | Not mentioned | Hardcoded in source — **undocumented tech debt** |

### Summary verdict
The product is feature-complete for Phases 1–3. The remaining gap is not features — it's **operationalization**: real payment credentials, real SMTP relay, real APNs cert, backup cron, and a production deployment checklist. The code quality is production-grade for an early-stage app. The 4 critical blockers (B1–B4) must all close before TestFlight invite can go out.
