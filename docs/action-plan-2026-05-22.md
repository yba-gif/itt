# ITT-Rehber — Action Plan

**Date:** 2026-05-22
**Source:** [project-analysis-report-2026-05-22.md](project-analysis-report-2026-05-22.md)
**Horizon:** 4 weeks (App Store submission target)

---

## Priority Ordering

### P0 — Urgent (do this week, blocks everything downstream)

| # | Action | Refs | Effort | Acceptance Criteria | Depends On |
|---|--------|------|--------|--------------------|------------|
| P0-1 | **Rotate every secret in `.env.prod`** | §3 Blocker #1 | 2h | All 14 keys regenerated; old values revoked; `.env.prod` uploaded to VPS; backend healthy on new creds; admin login works | — |
| P0-2 | **Force-push to scrub `.env.prod` from git history** | §3 Blocker #1 | 1h | `git log --all -- infra/hetzner/.env.prod` returns 0 commits; team notified that local clones must reset | P0-1 (so old keys are dead before history is rewritten) |
| P0-3 | **Merge `ui/design-system-sprints-1-5` → `main`** | §3 Blocker #4 | 0.5h | Production VPS tracking `main` again; no commit lag; production behavior unchanged | — |
| P0-4 | **Clean dupe listings on production** | §3 Blocker #5 | 1h | `scripts/cleanup-listings.py` archives the 2 period-prefix junk; manual review of 21 name-dupes; remaining listings count reported in `docs/data-cleanup-log.md` | redeploy first (script needs archive endpoint, which is on `main` after P0-3) |
| P0-5 | **Fix `admin.tgs-itt.ch` DNS** | §3 Blocker #8 | 0.2h | `curl -I https://admin.tgs-itt.ch` returns 200; cert valid | — |
| P0-6 | **Upload build 30 to TestFlight** | §1 dim 7, §2.3 | 1h | Build appears in TestFlight; at least 1 external tester invited | manual user action |

**P0 total: ~6h** (one full focused day)

### P1 — This Sprint (next 5 working days)

| # | Action | Refs | Effort | Acceptance Criteria | Depends On |
|---|--------|------|--------|--------------------|------------|
| P1-1 | **iOS smoke-test suite (5 tests)** | §3 Blocker #2 Solution A | 3h | `xcodebuild test` runs Directory decoding, Kanton.all completeness, Listing JSON round-trip, MarkdownView parse, OnboardingView state | — |
| P1-2 | **GitHub Actions — tests on PR** | §3 Blocker #3 Solution A | 3h | PR to `main` triggers `pytest apps/backend` + `xcodebuild test`; status badge on README | P1-1 (so the iOS job has something to run) |
| P1-3 | **Push notification end-to-end test on real device** | §3 Blocker #6 Solution A | 2h | Install TestFlight build → grant permission → admin sends `/admin/push/broadcast` → device receives + opens to correct route | P0-6 |
| P1-4 | **v1 claim flow end-to-end QA** | §2.3 v1 migration | 2h | One real v1-listing-owner signs up → "İlanlarınız hazır" banner appears → tap claim → listing shows in "İlanlarım" with `owner_id` set | P0-6, P0-4 |
| P1-5 | **Cert pinning implementation** | §3 Blocker #7 Solution A | 2h | `APIClient` URLSessionDelegate validates leaf cert against bundled DER; `#if DEBUG` allows localhost; app fails to connect if cert is swapped | — |
| P1-6 | **Production domain migration** | §2.3 domain migration | 4h | iOS `ITTAPIBaseURL` → `https://api.tgs-itt.ch`; Cloudflare DNS for both `api.` and `admin.` subdomains; certs issued; old `clawdcloud.xyz` redirects or 410s; one rebuild to ship | P0-5 |
| P1-7 | **Document the deploy + rotation runbook** | §1 dim 8 | 2h | `docs/runbook-deploy.md` covers redeploy, rollback, secret rotation, cert rotation, DB backup/restore | P0-1, P0-2 |

**P1 total: ~18h** (~3 working days)

### P2 — Next Sprint (week 2-3)

| # | Action | Refs | Effort | Acceptance Criteria |
|---|--------|------|--------|--------------------|
| P2-1 | German UI localization (DE) | §5 missing | 8h | `de.lproj/Localizable.strings`; SwiftUI strings extracted; language switcher in Profil; reviewed by a native speaker |
| P2-2 | Snapshot tests for key screens (10 screens) | §3 Blocker #2 Solution B | 8h | `swift-snapshot-testing` integrated; baseline snapshots committed; CI fails on visual regression |
| P2-3 | Backend image build + push GHCR via GitHub Actions | §3 Blocker #3 Solution B | 3h | Push to `main` builds `ghcr.io/yba-gif/itt-backend:latest`; redeploy script pulls instead of building locally |
| P2-4 | Automated TestFlight upload via GitHub Actions | §3 Blocker #3 Solution B | 6h | Tag `vX.Y.Z` triggers archive + altool upload using App Store Connect API key in GH Secrets |
| P2-5 | Saved-searches UI re-enable | §5 missing | 4h | "Aramayı kaydet" button on AraTab; visible in Profil > Kayıtlı Aramalar; tied to push notifications |
| P2-6 | Welcome Guide content surfacing | §5 missing | 2h | New users land on Welcome Guide after onboarding (one-shot); or NavigationLink prominent in Bilgi tab |
| P2-7 | Sealed secrets on prod VPS | §4 finding #4 | 4h | Server reads from `/opt/itt-secrets/.env`; redeploy script no longer overwrites; secrets rotation procedure documented |
| P2-8 | DB backup automation | §2.3 backup | 4h | Daily `pg_dump` cron writes to off-VPS storage (R2 bucket); documented restore drill |
| P2-9 | Refactor god-views | §4 finding #1, #2 | 6h | EtkinliklerTab split into 4 files; DesignSystem split into 3 files; build still green |
| P2-10 | Multi-canton listing display | (PRD §5.7) | 3h | Listings with `kantons=['BE','ZH']` shown with all chips; filter handles array overlap |

**P2 total: ~48h** (~1 full sprint)

### P3 — Backlog (post-launch / Phase 3 of PRD)

| # | Action | Refs | Effort |
|---|--------|------|--------|
| P3-1 | TWINT QR + bank-transfer paid-listing flow | §2.3 | 24h |
| P3-2 | PDF invoice generation (ReportLab) | §2.3 | 12h |
| P3-3 | Renewal cron — push 7 days before `paid_until` | §2.3 | 8h |
| P3-4 | Admin: content editor UI (replace API-only edits) | §1 dim 10 | 12h |
| P3-5 | Admin: push composer + audit log | §1 dim 10 | 16h |
| P3-6 | Full Turkish FTS dictionary (snowball or hunspell) | §2.2 FTS | 6h |
| P3-7 | French (FR) + English (EN) localizations | §5 missing | 12h |
| P3-8 | "Yakın çevremde" (CoreLocation + kanton match) | §2.3 | 12h |
| P3-9 | Crash reporter end-to-end (Sentry DSN active) | §1 dim 3 | 2h |
| P3-10 | Replace synthetic seed names with real or generic | §5 §3 Blocker #5 Solution B | 4h |

**P3 total: ~108h** (later)

---

## Sprint Breakdown

### Sprint 1 (Mon-Fri, ~26h work)
- **Day 1:** P0-1 → P0-2 → P0-3 (secrets rotation + main merge)
- **Day 2:** P0-4 → P0-5 → P0-6 (data cleanup + DNS + TestFlight build 30 upload)
- **Day 3:** P1-1 → P1-2 (iOS tests + CI bootstrap)
- **Day 4:** P1-3 → P1-4 (push end-to-end + claim flow QA on a real device)
- **Day 5:** P1-5 → P1-6 (cert pinning + domain migration) — ship build 31

### Sprint 2 (Mon-Fri, ~24h work)
- **Day 1-2:** P1-7 + P2-1 (runbook + German localization)
- **Day 3:** P2-2 (snapshot tests)
- **Day 4:** P2-3 → P2-4 (CI Docker push + TestFlight automation)
- **Day 5:** P2-5 → P2-6 (saved searches + welcome guide)

### Sprint 3 (week 3, ~24h work)
- **Day 1-2:** P2-7 → P2-8 (sealed secrets + DB backups)
- **Day 3:** P2-9 (refactor god-views)
- **Day 4:** P2-10 (multi-canton display)
- **Day 5:** App Store submission prep (screenshots, App Store Connect metadata, demo account, §3.1.3 reviewer notes)

### Sprint 4 (week 4)
- Apple review wait + respond to reviewer
- Hot-fix any review blockers
- P3 backlog starts after launch

---

## Dependency Map

```
P0-1 (rotate secrets) ─┬─→ P0-2 (scrub history)
                       └─→ P1-7 (runbook documents rotation)

P0-3 (main merge) ─→ P0-4 (cleanup uses archive endpoint on main)

P0-5 (admin DNS) ─→ P1-6 (full domain migration)

P0-6 (TestFlight build 30) ─┬─→ P1-3 (push test needs real device with build)
                            └─→ P1-4 (claim flow needs real user on build)

P1-1 (iOS tests) ─→ P1-2 (CI runs them)
P1-2 (CI) ────────→ P2-3 (Docker GHCR push) ─→ P2-4 (TestFlight auto-upload)

P0-2 (history scrub) + P1-7 (runbook) ─→ P2-7 (sealed secrets)
```

Critical path: **P0-1 → P0-2 → P0-6 → P1-3 → P1-4 → P1-6** is the chain that gates a real, end-to-end-verified, on-the-final-domain TestFlight build with rotated secrets.

---

## Quick Wins (<1h each)

| Quick Win | Effort | Effect |
|-----------|--------|--------|
| Cloudflare A-record for `admin.tgs-itt.ch` (P0-5) | 10min | Admin panel reachable on canonical domain |
| Run `scripts/cleanup-listings.py` (P0-4 part) | 5min after deploy | 2 period-prefix junk listings archived |
| Commit the uncommitted `ITTRehber.entitlements` (working tree dirty) | 2min | Repo clean |
| Add `CHANGELOG.md` with builds 22-30 entries | 30min | Onboarding ramp for future contributors |
| Set `APNS_USE_SANDBOX=false` validated by curling APNs JWT endpoint | 20min | Confirms APNs config sane before P1-3 |
| Rotate admin default password `changeme_admin` → strong | 5min | Closes a public-knowledge backdoor |
| Add CORS for `tgs-itt.ch` explicitly in `.env.prod` (currently `${DOMAIN:-itt-rehber.ch}` defaults) | 10min | Marketing site can hit API if needed |
| Add `OPENAI_API_KEY` rotation reminder note in `.env.prod.example` | 5min | Future devs see it |
| Grep for any remaining `clawdcloud.xyz` in source | 10min | Confirms domain migration completeness |
| Bump Traefik from v2.11 to v3 (or document why we stay) | 45min | Removes a deferred upgrade from the backlog |

---

## EXECUTIVE SUMMARY

**Project Health:** ITT-Rehber is at **🟡 Beta** maturity (6.2/10 across 10 dimensions). The product is functionally complete enough for closed-beta TestFlight users — all 10 directories live with 303 listings, AI working end-to-end, auth functional, content pages live, admin panel deployed. What's missing is the discipline layer: test coverage, CI/CD, secrets hygiene, and the secrets-in-git-history exposure that must be resolved before App Store submission.

**Three most critical findings:**
1. **`.env.prod` was tracked in git with production secrets** (DB password, JWT secret, SMTP, S3, APNs) until today's session — every secret needs to be rotated, and git history needs to be scrubbed before launch.
2. **iOS test coverage is 24 lines total** for 6,300 lines of Swift across 30 shipped builds — one regression in any of those builds could have shipped silently because nothing automated would catch it.
3. **Production was running the `main` branch which lagged the feature branch by 25+ commits** — including the AI route, search migration, archive endpoint, and recent content fixes — for an unknown window of time, meaning real users saw bugs we'd already fixed.

**Recommended first move:** Spend **today (~6 hours) on Sprint 1 Day 1-2** — rotate every secret, scrub history, merge to main, run the cleanup script, fix DNS, upload build 30. This single day reduces existential risk to zero and unblocks the entire critical path. Everything else can wait a sprint.
