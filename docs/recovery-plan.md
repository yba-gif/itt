# ITT-Rehber — Phase-by-Phase Recovery & Launch Plan

**Created:** 2026-05-22
**Audit baseline:** see `docs/audit-2026-05-22.md` (or scroll up in chat)
**Current state:** Backend live on Hetzner, 303 listings, admin panel works, iOS build 22 archived. AI not deployed; search broken; iOS work uncommitted.

---

## Phase 0 — Triage & Safety (today, 30 minutes)

**Goal:** stop the bleeding. Commit work, deploy the AI fix, verify nothing else broke.

### 0.1  Commit uncommitted iOS work (5 min) — SAFETY
```bash
cd /Users/bek/itt
git add apps/ios/ \
        infra/hetzner/.env.prod \
        apps/ios/ITTRehber/Resources/Assets.xcassets/ITTHeaderLogo.imageset/ \
        scripts/redeploy.sh
git commit -m "build 22: SIWA, markdown renderer, İTT AI tab, search top-right, cream Bilgi bg, flags logo"
git push origin ui/design-system-sprints-1-5
```
**Done when:** `git status` is clean and `git log @{u}..HEAD` is empty.

### 0.2  Deploy AI route + Gemini key (10 min)
```bash
ssh root@167.235.232.1 "cd /opt/itt && git fetch && git checkout ui/design-system-sprints-1-5"
bash scripts/redeploy.sh 167.235.232.1
```
**Done when:**
```bash
curl -s https://api.clawdcloud.xyz/openapi.json | python3 -c "import json,sys; print('/ai/chat' in json.load(sys.stdin)['paths'])"
# prints: True
```

### 0.3  Smoke-test AI from simulator (5 min)
Open simulator → İTT AI tab → tap "İsviçre'de nasıl doktor bulurum?" → wait for streamed response.
**Done when:** Gemini returns actual Turkish text.

### 0.4  Upload build 22 to TestFlight (10 min)
You handle this. IPA at `/tmp/ITTRehber22_export/ITTRehber.ipa`.

**Phase 0 exit criteria:** all 4 steps done. AI works in TestFlight when Apple finishes processing.

---

## Phase 1 — Critical Production Fixes (1–2 days)

**Goal:** fix functional bugs that real users will hit on day one.

### 1.1  Fix Turkish search — backend (4–6 hours)
**Problem:** `q=hukuk` returns 0 hits despite 12 hukuk listings. Search uses Postgres `simple` config + `unaccent`, missing Turkish stemming and directory-field indexing.

**Approach:**
- Add Turkish dictionary to Postgres FTS config: `CREATE TEXT SEARCH CONFIGURATION turkish_unaccent ( COPY = turkish )`
- Rebuild `search_tsv` trigger to include `directory`, `kantons`, `category`, `name`, `description`
- Add Alembic migration
- Test: `q=hukuk` should return all 12 hukuk listings; `q=İsviçre` should not 500

**Verification:**
```bash
for term in hukuk avukat İsviçre okul doktor; do
  curl -s "https://api.clawdcloud.xyz/search?q=$term" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'{sys.argv[1]:10s} → {d.get(\"total\",0)} hits'" "$term"
done
```

### 1.2  Clean duplicate / dirty listings (1–2 hours)
**Problem:** Top 2 listings on `/listings` both named `.İsviçre Türk Toplumu İTT` (period prefix, dupes).

**Approach:**
- Connect to prod DB via admin panel or direct psql via SSH
- Run audit query: `SELECT id, name, created_at FROM listings WHERE name LIKE '.%' OR name IN (SELECT name FROM listings GROUP BY name HAVING COUNT(*) > 1)`
- Decide canonical row per duplicate group; soft-delete or hard-delete others
- Document in `docs/data-cleanup-log.md`

### 1.3  Seed initial events (2 hours)
**Problem:** 0 events on production. Etkinlikler tab shows empty state.

**Approach:**
- Author 5–10 real TGS-ITT events for the next 60 days (kermes, dil kursu, bayram, panel, mevlid)
- Either bulk-insert via admin panel or write `scripts/seed-events.py`
- Use realistic kantons + dates

### 1.4  Fix `admin.tgs-itt.ch` DNS (30 min)
**Problem:** HTTP 000 on `admin.tgs-itt.ch`. Marketing domain `tgs-itt.ch` works (200) but admin subdomain doesn't resolve.

**Approach:**
- Check Cloudflare DNS panel for `tgs-itt.ch`
- Add A record `admin → 167.235.232.1` (matching `admin.clawdcloud.xyz`)
- Wait for traefik to provision TLS cert (30–60 sec on first request)

**Phase 1 exit criteria:**
- Search returns ≥1 hit for `hukuk`, `avukat`, `okul`, `doktor`
- No duplicate listings on first page of `/listings`
- 5+ upcoming events visible in Etkinlikler tab
- `admin.tgs-itt.ch` serves the admin panel

---

## Phase 2 — Content, QA & Polish (3–5 days)

**Goal:** ship a beta that's pleasant to use, not just functional.

### 2.1  TestFlight closed beta (parallel — 5 days)
- Invite 10–15 Turkish-Swiss testers via TestFlight
- Slack/WhatsApp group for feedback
- Triage feedback into 3 buckets: bug / polish / Phase 3 feature

### 2.2  Polish backlog (rolling, as testers find issues)
Likely items based on the simulator walk-through:
- Detail view phone numbers should be tappable (currently text)
- Listing images: 77 migrated but coverage unknown — check ratio of listings w/ vs without image
- Empty-state copy review (e.g. when search returns 0)
- Pull-to-refresh haptic feedback
- Accessibility: VoiceOver labels on icon-only buttons

### 2.3  Welcome Guide content (1–2 days)
**Problem:** `welcome` page is decent (859 chars) but generic. PRD calls this "Faz 2 Welcome Guide" — should be a real onboarding doc.

**Approach:**
- Write proper sections: Oturum İzni (B/C/L), Krankenkasse seçimi, Çocuk doğumu sonrası belgeler, Türkçe okul kayıt, Cami bilgileri
- Each section: 2–3 short paragraphs + link to relevant Rehber category
- Update via `PUT /content/welcome`

### 2.4  Image coverage audit (2 hours)
```bash
# Count listings with vs without image_url
TOKEN=...
curl -s "https://api.clawdcloud.xyz/listings?page_size=300" -H "Authorization: Bearer $TOKEN" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); items=d['items']; print(f'With image: {sum(1 for i in items if i.get(\"image_url\"))}, without: {sum(1 for i in items if not i.get(\"image_url\"))}')"
```
If <50%, prioritize generating fallback images (initials or category icon).

**Phase 2 exit criteria:**
- 10+ beta testers using the app daily
- Crash rate <1% (Sentry)
- Welcome Guide has real content
- ≥80% of listings have images (or quality fallbacks)

---

## Phase 3 — Production Readiness (1–2 weeks)

**Goal:** be ready for App Store review and public launch.

### 3.1  Push notifications end-to-end (3 days)
**Current state:** `/push/register` endpoint exists, APNS_USE_SANDBOX=false, but never tested end-to-end.

**Tasks:**
- Verify APNs cert configured in `.env.prod` (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, key file mounted)
- Test on real device (simulator can't receive push)
- Trigger via admin panel: `/admin/push/broadcast` with category filter
- Verify delivery + tap routes to correct listing
- Saved-search notification trigger when matching listing approved

### 3.2  Cert pinning (1 day) — P4 TODO already in APIClient.swift
- Export `api.clawdcloud.xyz` cert as DER
- Implement `URLSessionDelegate` per the existing comment block
- Guard with `#if DEBUG` to allow localhost
- Test: app should fail to connect if cert is swapped

### 3.3  v1 migration claim flow QA (1 day)
- Sign up with email that matches a claimable v1 listing
- Verify "v1 ilanlarınız hazır" banner appears
- Tap claim → verify ownership transfer in DB
- Verify ListingDetailView shows the listing under "İlanlarım"

### 3.4  Performance & error handling (2 days)
- Audit all `try await` calls in iOS for empty-state vs error-state UX
- Sentry error rate review: anything noisy?
- Cold start time on iPhone 12 (target <2s to interactive)
- Memory: 303 listings shouldn't bloat — confirm pagination is actually paginating
- Offline mode: SwiftData cache verified working when network drops

### 3.5  Legal review (1 day)
- Privacy policy reviewed by a Swiss lawyer (nFADP compliance)
- Terms of Service reviewed
- Cookie/tracking disclosure if needed
- App Store privacy nutrition label completed

### 3.6  App Store submission prep (2 days)
- Screenshots for all required sizes (6.7", 5.5", iPad)
- App description (Turkish + German + French + English)
- Keywords + ASO
- Demo account credentials for review team
- §3.1.3(b) reviewer notes (reader app exception for paid listings) — per PRD §10 Phase 4

**Phase 3 exit criteria:**
- Push notifications proven working
- Cert pinning live
- App Store submission ready to upload

---

## Phase 4 — Monetization (PRD Phase 3, ~2 weeks, optional pre-launch)

**Goal:** enable paid listings. Per PRD §10, this is the originally-planned Phase 3.

### 4.1  TWINT / QR payment instructions (3 days)
- Generate TWINT QR per listing tier (CHF 60/yr basic, CHF 180/yr featured)
- "Bank transfer instructions" PDF generation
- Admin marks invoice paid → listing transitions to active + paid_until set

### 4.2  PDF invoice generation (2 days)
- WeasyPrint container in docker-compose
- Template: TGS-ITT letterhead, listing details, VAT (Switzerland MWST 8.1%)
- `/invoices/{id}/pdf` endpoint returns PDF

### 4.3  Renewal automation (2 days)
- Cron job: 7 days before `paid_until` → push notification "Yenileme zamanı"
- 1 day after expiry → listing transitions to `expired` (per PRD §6.3)
- Admin can manually extend

**Phase 4 exit criteria:**
- One paid listing flowed end-to-end (signup → submit → pay → admin marks paid → goes live)

---

## Phase 5 — Launch (1 week)

**Goal:** public launch. Per PRD §10 Phase 4.

### 5.1  App Store submission + review (5–10 days for Apple)
- Submit build 23+ with all Phase 1–3 fixes
- Respond to reviewer questions within 24h
- Plan for ~2 rejection cycles (typical for fresh-IP apps with payments)

### 5.2  v1 deprecation banner (1 day)
- Old itt-rehber.ch shows banner: "TGS-ITT Rehber 2.0 yayında — App Store'dan indirin"
- Auto-redirect to new App Store link after 30 days

### 5.3  Launch communications (1 day)
- TGS-ITT email blast to existing newsletter
- WhatsApp groups in major cantons (Zürich, Genf, Bern, Basel)
- Optional: TR-CH Konsolosluk posts

### 5.4  Day-1 monitoring (ongoing)
- Sentry dashboard
- Sign-up rate
- App Store rating watch
- Hot-fix readiness (be ready to ship build 24 within 24h if needed)

**Phase 5 exit criteria:**
- Live on App Store (Switzerland storefront minimum)
- ≥100 day-1 downloads
- No P0 bugs in first week

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Gemini API quota / billing | Medium | High | Set billing alert; monitor `/ai/chat` 429s; fallback to cached canned answers |
| Apple rejects (§3.1.3 reader app) | High | High | PRD §10 says rejection 2–3 cycles is expected; allocate 2 weeks buffer |
| Search rewrite breaks existing flows | Low | Medium | Alembic migration with rollback; staging test first |
| Push deliverability low (APNs cert issues) | Medium | Medium | Test on multiple devices; have backup of in-app notifications |
| Hetzner VPS goes down | Low | High | Set up Hetzner backup volumes; document restore procedure |
| Cert pinning breaks dev | Low | Low | Already guarded with `#if DEBUG` per existing TODO |
| Beta tester feedback overwhelming | High | Low | Triage discipline: bug / polish / future. Don't try to ship everything |

---

## Timeline Summary

```
Phase 0  ━ today (30 min)         [you do steps; I verify]
Phase 1  ━━━━ 1–2 days             [search + data + DNS]
Phase 2  ━━━━━━━━━━━ 3–5 days       [beta + polish, parallel]
Phase 3  ━━━━━━━━━━━━━━━ 1–2 weeks  [push + cert pinning + submission prep]
Phase 4  ━━━━━━━━━━━━━━━ 2 weeks    [monetization — can run parallel w/ Phase 3]
Phase 5  ━━━━━━━━━━━━━━ 1 week + Apple's queue (5–10d)
```

**Soonest realistic public launch: ~4 weeks from today if Phase 4 deferred, ~6 weeks if Phase 4 in.**

**Demo-ready (closed TestFlight + working AI + cleaned data): end of Phase 1 = ~3 days.**
