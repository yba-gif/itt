# ITT-Rehber 2.0 — Action Plan
**Date:** 2026-05-20  
**Status at writing:** Phases 1–3 code-complete. Phase 4 (TestFlight → App Store) not started.  
**Goal:** Reach a deployable, TestFlight-ready state with zero silent-failure modes in the money path.

---

## Priority ordering

| Priority | Label | Meaning |
|----------|-------|---------|
| P0 | Launch-gate | App cannot ship to any user without this |
| P1 | Ops-gate | Production will silently malfunction without this |
| P2 | UX-debt | User-visible bug or confusing experience |
| P3 | Tech-debt | Code quality, maintainability, future risk |

---

## P0 — Launch-gate (do before first TestFlight invite)

### P0-1 · Fix MyListingsView to call `/listings/mine/all`
**Blocker:** B2 — user-visible data bug  
**Effort:** 30 min  
**Files:**
- `apps/ios/ITTRehber/Services/APIClient.swift` — add `func myListings() async throws -> [Listing]` calling `GET /listings/mine/all`
- `apps/ios/ITTRehber/Views/Tabs/ProfilTab.swift` — change `MyListingsView.loadListings()` to call `APIClient.shared.myListings()`

```swift
// APIClient.swift — add:
func myListings() async throws -> [Listing] {
    try await get("/listings/mine/all")
}

// ProfilTab.swift MyListingsView.loadListings() — replace:
listings = try await APIClient.shared.listings(directory: nil, kanton: nil, query: nil).items
// with:
listings = try await APIClient.shared.myListings()
```

---

### P0-2 · Replace hardcoded payment credentials with env config
**Blocker:** B1 + AP3 — every PDF invoice sent to real users has wrong payment details  
**Effort:** 45 min  
**Files:**
- `apps/backend/app/config.py` — add 5 new `Optional[str]` settings with dev placeholders
- `apps/backend/app/services/invoice.py` — read from `settings.*` instead of module constants
- `.env.example` — document the 5 new keys

```python
# config.py — add to Settings:
payee_name: str = "Roar (Yusuf Berkan Altun)"
payee_address: str = "Switzerland"
twint_phone: str = "+41 79 000 00 00"  # dev placeholder
bank_iban: str = "CH00 0000 0000 0000 0000 0"  # dev placeholder
bank_name: str = "Bank TBD"  # dev placeholder

# invoice.py — replace module constants with:
from app.config import settings
PAYEE_NAME = settings.payee_name
TWINT_PHONE = settings.twint_phone
# etc.
```

```ini
# .env.example — add:
PAYEE_NAME=Roar (Yusuf Berkan Altun)
PAYEE_ADDRESS=Switzerland
TWINT_PHONE=+41 79 000 00 00
BANK_IBAN=CH00 0000 0000 0000 0000 0
BANK_NAME=Bank TBD
```

---

### P0-3 · Set DEVELOPMENT_TEAM and wire real SIWA
**Blocker:** B3 + B4 — device builds fail to sign; SIWA shows placeholder alert  
**Effort:** 1–2 hours (Apple Developer account required)  
**Files:**
- `apps/ios/project.yml` — set `DEVELOPMENT_TEAM: <10-char Team ID>`
- `apps/ios/ITTRehber/Views/Auth/SIWAButtonView.swift` (or wherever the placeholder lives) — replace `UIAlertController` stub with real `ASAuthorizationAppleIDButton`

If the Apple Developer account is not ready, the minimum acceptable action is to **remove the SIWA button from the UI entirely** (show only email/password). Apple rejects apps with non-functional SIWA buttons.

---

### P0-4 · Add `LETSENCRYPT_EMAIL` to `.env.example`
**Blocker:** B9 + AP6 — prod Traefik ACME will fail silently  
**Effort:** 5 min  
**File:** `.env.example`

```ini
# Hetzner prod — TLS
LETSENCRYPT_EMAIL=your@email.com
```

---

## P1 — Ops-gate (do before first real user on prod)

### P1-1 · Configure SMTP relay
**Blocker:** B6 — invoice emails never sent in prod  
**Effort:** 1 hour  
**Recommended relay:** Resend (free tier: 3 000 emails/month, excellent deliverability, simple API key SMTP bridge)  
**Steps:**
1. Create account at resend.com, verify domain `itt-rehber.ch`
2. Add SMTP endpoint to prod `.env`: `SMTP_HOST=smtp.resend.com SMTP_PORT=587 SMTP_USER=resend SMTP_PASSWORD=<api_key>`
3. Test with `make up && python -c "from app.services.email import send_email; send_email('you@email.com', 'test', 'hello')"` from inside the backend container

---

### P1-2 · Configure APNs
**Blocker:** B7 — push notifications never delivered  
**Effort:** 1 hour  
**Steps:**
1. In Apple Developer Portal: create APNs key (`.p8`), download once — it cannot be re-downloaded
2. Copy `.p8` to Hetzner VPS at `/etc/itt/apns.p8`; mount as read-only volume in prod compose: `- /etc/itt/apns.p8:/run/secrets/apns.p8:ro`
3. Set in prod `.env`: `APNS_KEY_ID=<10-char> APNS_KEY_P8_PATH=/run/secrets/apns.p8 APNS_USE_SANDBOX=false APPLE_TEAM_ID=<10-char>`
4. Verify `services/push.py` reads the path correctly (it does — already wired)

---

### P1-3 · Schedule expire-and-remind.py cron
**Blocker:** B5 — paid listings never auto-expire; renewal reminders never sent  
**Effort:** 15 min  
**Fix:** Add to Hetzner VPS crontab:
```
# ITT-Rehber — daily expiry + renewal reminders (3am Zurich time)
0 3 * * * docker exec itt_backend_1 python /app/scripts/expire-and-remind.py >> /var/log/itt-expiry.log 2>&1
```
Alternatively, add a `scheduler` service to `docker-compose.prod.yml` running `supercronic` with a crontab mounted as a config file.

---

### P1-4 · Add silent-failure logging to email send
**Blocker:** AP2 — `except Exception: pass` hides SMTP failures  
**Effort:** 10 min  
**File:** `apps/backend/app/routes/listings.py:169`

```python
# Replace:
except Exception:
    pass
# With:
except Exception as exc:
    import logging
    logging.getLogger(__name__).warning(
        "Invoice email failed for %s: %s", invoice.invoice_number, exc, exc_info=True
    )
```

---

### P1-5 · Add rate limiting to auth endpoints
**Blocker:** B10 — brute-force on `/auth/email/login`  
**Effort:** 1 hour  
**Options:**
- **Option A (preferred):** `slowapi` middleware — 5 requests/minute per IP on `/auth/email/login` and `/auth/email/signup`
- **Option B:** nginx `limit_req_zone` in the Traefik/nginx layer if running behind a reverse proxy

```python
# main.py
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# routes/auth.py
@router.post("/email/login")
@limiter.limit("5/minute")
async def email_login(request: Request, ...):
```

---

### P1-6 · Add Postgres healthcheck + DB backup
**Blocker:** B8 + B9  
**Effort:** 30 min  
**File:** `infra/hetzner/docker-compose.prod.yml`

```yaml
# Add to postgres service:
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
  interval: 10s
  timeout: 5s
  retries: 5

# Add depends_on to backend:
backend:
  depends_on:
    postgres:
      condition: service_healthy
```

Add to VPS crontab (daily backup to Hetzner Storage Box):
```
0 2 * * * docker exec itt_postgres_1 pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > /mnt/storagebox/itt-$(date +\%Y\%m\%d).sql.gz
```

---

## P2 — UX-debt (fix before public App Store launch)

### P2-1 · Extract `_to_public()` to shared schema function
**Blocker:** AP1 — drift risk as listing schema evolves  
**Effort:** 20 min  
**File:** `apps/backend/app/schemas/listing.py` — add module-level function `listing_to_public(listing: Listing) -> ListingPublicOut`; update both `routes/listings.py` and `routes/search.py` to import and call it.

---

### P2-2 · Validate `payment_method` enum in admin Payments page
**Blocker:** B13  
**Effort:** 15 min  
**File:** `apps/admin/src/pages/Payments.tsx` — ensure the mark-paid buttons hard-code `"twint"` and `"bank_transfer"` string literals rather than free-text input.

---

### P2-3 · Generate `docs/api.md`
**Blocker:** B14 — referenced in architecture.md but file doesn't exist  
**Effort:** 10 min  
Add to `Makefile`:
```makefile
docs: up
	curl -s http://localhost:8000/openapi.json | python -m json.tool > docs/openapi.json
	@echo "# API Reference\n\nGenerated from OpenAPI spec. Import docs/openapi.json into Swagger UI or Postman.\n" > docs/api.md
	@echo "Spec: \`docs/openapi.json\`" >> docs/api.md
```

---

### P2-4 · Implement `--source=sheets` in migration script or gate it clearly
**Blocker:** B11  
**Effort:** 2–8 hours depending on Google Sheets API setup  
If not implementing before launch, at minimum replace the silent `NotImplementedError` with a clear error message and note:
```python
sys.exit(
    "ERROR: --source=sheets is not yet implemented.\n"
    "Use --source=mock for dry-run, or implement Google Sheets pull per docs/architecture.md Q-migration."
)
```

---

## P3 — Tech-debt (Phase 4 or beyond)

### P3-1 · Certificate pinning in APIClient.swift
Wire `URLSessionDelegate` pinning against the production TLS cert. Defer until the Hetzner VPS TLS cert is issued and stable (changes on cert renewal — pin the public key hash, not the cert itself).

### P3-2 · Decompose listings.py create_listing()
Extract invoice issuance + email dispatch into a `submission_service.py` with a single `async def submit_listing(db, user, payload) -> tuple[Listing, Invoice | None]` function. Keeps the route handler focused on HTTP concern only.

### P3-3 · Decompose APIClient.swift
Split by domain: `ListingsAPIClient`, `EventsAPIClient`, `AuthAPIClient`. Protocol-based for testability. Needed before Phase 4 adds background refresh and background push handling.

### P3-4 · Add React admin tests
At minimum: happy-path Payments mark-paid with `@testing-library/react` + `msw` for mock API. Queue filter tests.

### P3-5 · Add script integration test for expire-and-remind.py
Call the script as a subprocess from `test_phase3.py` against the test DB and verify state transitions, rather than just manipulating DB state directly.

### P3-6 · Move DEVELOPMENT_TEAM into a local .xcconfig
Create `apps/ios/LocalDev.xcconfig` (gitignored) holding `DEVELOPMENT_TEAM = <your-id>`. Reference from `project.yml`. This allows different team members to set their own team ID without touching version-controlled files.

---

## Sprint grouping (suggested)

### Sprint A — "Make prod honest" (1–2 days)
P0-1 (MyListings bug) · P0-2 (payment creds) · P0-4 (LETSENCRYPT_EMAIL) · P1-4 (silent email logging) · P2-2 (payment_method enum) · P2-3 (generate api.md)

All code changes, zero infrastructure. Can be done without access to Apple Developer or Hetzner.

### Sprint B — "Wire the money path" (1 day + Apple/Hetzner access)
P0-3 (DEVELOPMENT_TEAM + SIWA) · P1-1 (SMTP relay) · P1-2 (APNs) · P1-3 (expiry cron) · P1-6 (postgres healthcheck + backup)

Requires: Apple Developer account, Hetzner VPS access, domain DNS configured.

### Sprint C — "TestFlight hardening" (1 day)
P1-5 (rate limiting) · P2-1 (extract _to_public) · P2-4 (migration script gate) · First TestFlight invite

### Sprint D — "App Store + Phase 4" (Phase 4 scope)
P3-1 through P3-6 · CI/CD (GitHub Actions + TestFlight deploy) · v1 sunset banner · Google Sheets migration · App Store submission

---

## Dependency map

```
P0-3 (Apple Dev account)
  └── required for: P0-3 SIWA, P1-2 APNs

P1-1 (SMTP)
  └── required for: invoice emails working end-to-end (P0-2 is prereq for correct content)
  └── P0-2 must land first so emails contain real bank details

P0-2 (payment creds in env)
  └── required for: P1-1 to be useful (email with real payment details)
  └── required for: prod deploy (can't ship with placeholder IBAN)

P1-6 (DB backup)
  └── required before: any real user data on prod

P1-3 (expiry cron)
  └── required before: first paid listing expires (month 1 free ends 30 days after first user submits)

P0-1 (MyListings fix)
  └── standalone — no dependencies, immediate user impact fix
```

### Critical path to TestFlight
```
P0-2 → P1-1 → P0-3 → P1-2 → P1-6 → Sprint B complete → TestFlight invite
                              P0-1 (can be done in parallel, no dependency)
```

---

## Quick wins (under 30 minutes each)

| Win | File | Time |
|-----|------|------|
| Fix MyListings bug | ProfilTab.swift + APIClient.swift | 20 min |
| Log silent email failures | routes/listings.py:169 | 5 min |
| Add LETSENCRYPT_EMAIL to .env.example | .env.example | 2 min |
| Gate `--source=sheets` with clear sys.exit | scripts/migrate-from-v1.py | 5 min |
| Validate payment_method in Payments.tsx | admin/src/pages/Payments.tsx | 10 min |
| Generate docs/api.md via make target | Makefile | 10 min |
| Extract `_to_public()` to schemas/listing.py | listings.py + search.py | 15 min |

**Total: ~67 minutes for 7 code improvements, all low-risk, no infrastructure access required.**
