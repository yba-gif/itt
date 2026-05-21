# ITT Rehber iOS — UI/UX Action Plan
**Date:** 2026-05-21  
**Source:** `ui-ux-analysis-report-2026-05-21.md`  
**Overall UX Maturity:** 🟠 Functional (Alpha) — 5.1/10  

---

## Quick Wins (< 1 hour each, ship immediately)

These can be batched into a single commit — no design decisions needed.

| # | Fix | File | Time | Done When |
|---|-----|------|------|-----------|
| QW-1 | Replace SIWA footer: "Apple ile Giriş yakında aktif olacak. Şimdilik e-posta ile devam edebilirsiniz." | `LoginView.swift` | 5 min | No implementation detail visible to users |
| QW-2 | Add "Tekrar dene" button to every `alert("Hata")` that has a `load()` function | All data-loading views | 30 min | Every error dialog has at least one retry action |
| QW-3 | Show canton full name on EventRow: `Kanton.all.first(where: { $0.code == event.kanton })?.nameTR ?? event.kanton` | `EtkinliklerTab.swift` | 15 min | EventRow shows "Zürich" not "ZH" |
| QW-4 | Apply `.tint(Color.tgsRed)` to all `Form` views | `LoginView.swift`, `SubmitListingView.swift`, `SubmitEventView.swift` | 20 min | Buttons/toggles/pickers in Forms use TGS red not system blue |
| QW-5 | Change AraTab placeholder: "Tüm rehberlerde ara…" | `AraTab.swift` | 2 min | Placeholder is imperative |
| QW-6 | Add `tgsAmber` / `tgsAmberBg` tokens to DesignSystem; use in OfflineBanner | `DesignSystem.swift`, `DirectoryListView.swift` | 15 min | OfflineBanner colours are design-system tokens |
| QW-7 | Sort BilgiTab emergency numbers by urgency (144 Tıbbi, 117 Polis, 118 İtfaiye, 145 Zehir, 140 Yol) | `BilgiTab.swift` | 10 min | Medical emergency is first in the list |
| QW-8 | `AccessibilityLabel` on all 4 ActionButtons: "Ara", "E-posta gönder", "Haritada aç", "Web sitesini aç" | `DirectoryDetailView.swift` | 20 min | VoiceOver reads action label correctly |
| QW-9 | Regenerate app icon with TGS red `#B82030` background + "TGS" white text | `AppIcon.appiconset` (Python script) | 30 min | No blue in icon; matches current brand colour |
| QW-10 | Hide `SavedSearchesView` row in ProfilTab behind `#if DEBUG` flag until AraTab has save-search button | `ProfilTab.swift` | 5 min | No dead-end navigation to empty saved searches |

**Total quick-wins: ~2.5 hours**

---

## Dependency Map

```
[Design Tokens] ──────────────► [Typography Scale] ──► [Dynamic Type]
      │                                 │
      └──► [TGS Form Component] ──────► [Login / Submit flows]
                                         │
                  [Error States] ◄───────┘
                       │
                       └──► [Retry Logic] ──► [Offline UX]

[Accessibility Labels] ─ independent, can ship anytime
[Onboarding Banner]   ─ independent, can ship anytime
[Debounce Search]     ─ independent, can ship anytime
[App Icon]            ─ independent, can ship anytime
```

**Block A:** Design Tokens (type scale, radius constants) must land before Typography refactor and TGS Form components — both depend on the same tokens.  
**Block B:** TGS Form Component must land before Login/Submit redesign.  
**Block C:** Error State reusable component can be built independently but should be reviewed alongside Retry Logic additions.

---

## P0 — Blocks Core Task (Ship Before TestFlight Public)

These must be resolved before inviting external testers.

### P0-1: Retry Action in Error Dialogs
- **Analysis ref:** Blocker #3, Anti-Patterns (Missing Feedback)
- **Effort:** 2 hours
- **Acceptance criteria:**
  - Every `alert("Hata")` that wraps a network call has a "Tekrar Dene" button that re-fires the load function
  - Dismissing with "Kapat" clears the error state without triggering a load
  - Retry does not stack duplicate tasks if already loading
- **Files:** `DirectoryListView.swift`, `DirectoryDetailView.swift`, `EtkinliklerTab.swift`, `AraTab.swift`, `BilgiTab.swift`

### P0-2: FilterBar Search Debounce
- **Analysis ref:** Blocker #5
- **Effort:** 2 hours
- **Acceptance criteria:**
  - No API call fires until 400ms after the last keystroke in the search field
  - Rapid typing (3 chars/sec) produces exactly 1 network request, not N
  - Clearing the field immediately shows cached/empty state without a delay
- **Files:** `DirectoryListView.swift`, `FilterBar.swift`

### P0-3: SubmitListingView — Required Field Indication
- **Analysis ref:** Anti-Patterns (Form Friction), Blocker #3
- **Effort:** 2 hours
- **Acceptance criteria:**
  - A validation summary "Zorunlu: İsim, Kanton, Görsel" appears above submit button when fields are missing
  - Image upload section has a visible "* zorunlu" badge before upload
  - Submit button tooltip or accessibility hint explains why it is disabled

---

## P1 — This Sprint (Next 2 Weeks)

### P1-1: TGS Red Tint on All Form Views
- **Analysis ref:** Blocker #2 (Solution A), Quick Win QW-4
- **Effort:** 1 hour
- **Acceptance criteria:**
  - All `Form`, `Picker`, `Toggle`, `DatePicker`, `SecureField`, `Button(.borderedProminent)` inside Form views render in TGS red `#B82030`
  - No blue system colour visible in LoginView, SubmitListingView, or SubmitEventView
- **Files:** `LoginView.swift`, `SubmitListingView.swift`, `EtkinliklerTab.swift` (SubmitEventView)

### P1-2: Welcome Banner (First-Run Onboarding)
- **Analysis ref:** Blocker #1 (Solution A), Journey Analysis §5
- **Effort:** 3 hours
- **Acceptance criteria:**
  - On first launch (`UserDefaults.bool(forKey: "hasSeenWelcome") == false`), a dismissible card appears at the top of RehberTab above the grid
  - Banner text: "İsviçre'deki Türk uzman ve etkinlik rehberi. Bir kategori seçerek başlayın." + "Anladım" dismiss button
  - Banner does not appear on subsequent launches
  - Banner renders on iPhone SE (375pt) without clipping
- **Files:** `RehberTab.swift`

### P1-3: Directory Tile Category CTA
- **Analysis ref:** Blocker #7, Journey Analysis §5
- **Effort:** 2 hours (includes adding `cta` property to `Directory.swift`)
- **Acceptance criteria:**
  - Each tile shows a category-specific CTA instead of "İncele →": e.g., "Uzmanları gör", "Avukatları gör", "Etkinliklere bak"
  - CTA strings are in `Directory.swift` as a computed `cta: String` property
  - All 10 CTAs are distinct and accurately describe the content
- **Files:** `Models/Directory.swift`, `Views/Tabs/RehberTab.swift`

### P1-4: Accessibility Pass — Priority Surfaces
- **Analysis ref:** Blocker #4 (Solution A), Anti-Patterns (Accessibility Gaps)
- **Effort:** 3 hours
- **Acceptance criteria:**
  - `ActionButton` has `.accessibilityLabel` on all 4 variants (call/email/map/web)
  - `AsyncImage` in DirectoryDetailView and EventDetailView has `.accessibilityLabel`
  - `DirectoryTile` has `.accessibilityLabel(directory.titleTR)` and `.accessibilityHint(directory.cta)`
  - `TGSEyebrow` has `.accessibilityLabel("İsviçre'de Türk topluluğu")` (lowercase, no shouting)
  - VoiceOver can navigate and activate every interactive element in the primary JTBD #1 flow
- **Files:** `DirectoryDetailView.swift`, `EtkinliklerTab.swift`, `RehberTab.swift`, `DesignSystem.swift`

### P1-5: App Icon Brand Update
- **Analysis ref:** Blocker #6 (Solution A)
- **Effort:** 1 hour
- **Acceptance criteria:**
  - All 15 icon sizes regenerated with TGS red `#B82030` background
  - Symbol on icon is either "TGS" or a crescent/globe on white (TBD with brand owner)
  - Icon is not blue anywhere
  - Build uploads to TestFlight with new icon
- **Files:** `Resources/Assets.xcassets/AppIcon.appiconset/`

### P1-6: Type Scale Tokens in DesignSystem
- **Analysis ref:** Score §1 Typography 4/10, Dependency Map Block A
- **Effort:** 4 hours
- **Acceptance criteria:**
  - `DesignSystem.swift` exports a `TGSFont` namespace with at minimum: `display`, `title`, `headline`, `body`, `callout`, `subheadline`, `caption`, `micro`
  - Each token maps to a SwiftUI `Font` using `.system(size: N, weight:, design: .default)` with `@ScaledMetric` wrapping for Dynamic Type support
  - Body text (≥ 14pt) across the app uses `TGSFont.body` or semantic equivalents — no raw `size: 14` literals in view files
- **Files:** `DesignSystem.swift`, then systematic find-replace in view files

### P1-7: Corner Radius & Spacing Tokens
- **Analysis ref:** Anti-Patterns (Visual Debt — mixed radii)
- **Effort:** 1 hour
- **Acceptance criteria:**
  - `DesignSystem.swift` exports `TGSRadius.card = 24`, `TGSRadius.inner = 16`, `TGSRadius.pill = 999`, `TGSRadius.field = 12`
  - No magic-number `cornerRadius` values in any view file other than these 4
  - `TGSSpacing` exports: `xs = 4`, `sm = 8`, `md = 12`, `lg = 16`, `xl = 20`, `xxl = 24`

---

## P2 — Next Sprint

### P2-1: Skeleton Loading Screens
- **Analysis ref:** Score §5 Interaction 3/10, Anti-Patterns (Missing Feedback)
- **Effort:** 6 hours
- **Acceptance criteria:**
  - `DirectoryListView` shows 4 skeleton rows (animated shimmer) while loading the first page
  - `EtkinliklerTab` shows 3 skeleton event rows
  - Skeleton is dismissed once the first data batch arrives, not when all images load
  - `SkeletonView` component lives in a new `Views/Common/SkeletonView.swift`

### P2-2: Favourite Toggle Animation + Haptic
- **Analysis ref:** Anti-Patterns (Missing Feedback)
- **Effort:** 2 hours
- **Acceptance criteria:**
  - Tapping "Favorilere ekle" triggers `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
  - The star icon animates: `.scaleEffect(1.3)` → `1.0` with `.spring(response: 0.3, dampingFraction: 0.5)` on state change
  - Tapping "Favorilerden çıkar" shows a 3-second undo toast ("Favorilerden çıkarıldı · Geri Al") before making the API call

### P2-3: TGS Form Component (System-Level Fix for Forms)
- **Analysis ref:** Blocker #2 (Solution B)
- **Effort:** 16 hours
- **Acceptance criteria:**
  - New `TGSFormSection` component renders a `VStack` with a section label and `TGSInnerCard`-styled content area (no UIKit table cells)
  - `LoginView`, `SubmitListingView`, `SubmitEventView` are rebuilt using `TGSFormSection`
  - All three screens pass visual regression: cream background, TGS red interactive elements, no grey inset cells visible
  - Form fields support same keyboard types, autofill, and submit handling as before
  - **Dependency:** P1-6 (type tokens) and P1-7 (spacing tokens) must be complete first

### P2-4: Multi-Step SubmitListingView
- **Analysis ref:** Journey Analysis §5 JTBD #3, Complexity Map (Hard Surfaces)
- **Effort:** 10 hours
- **Acceptance criteria:**
  - SubmitListingView is split into 3 steps: (1) Basics + Photo, (2) Contact + Region, (3) Package + Review
  - A step progress indicator ("Adım 2 / 3") is visible at the top
  - "İleri" / "Geri" navigation between steps preserves all state
  - Final Review step shows a read-only summary of all inputs before submission
  - **Dependency:** P2-3 (TGS Form Component)

### P2-5: Error State Inline Component
- **Analysis ref:** Blocker #3 (Solution B)
- **Effort:** 5 hours
- **Acceptance criteria:**
  - New `ErrorStateView(message: String, onRetry: (() -> Void)?)` component in `Views/Common/`
  - Used in `DirectoryListView`, `EtkinliklerTab`, `DirectoryDetailView` to replace bare alert dialogs for initial-load failures
  - Renders: icon + message + "Tekrar Dene" button (if `onRetry` is not nil)
  - Alert dialogs retained only for action-level errors (e.g., favourite failed)

### P2-6: EventRow Date Grouping
- **Analysis ref:** Journey Analysis §5 JTBD #2
- **Effort:** 4 hours
- **Acceptance criteria:**
  - EtkinliklerTab groups events by week: "Bu Hafta", "Gelecek Hafta", "Bu Ay", "Daha Sonra"
  - Each section header shows the week span (e.g., "26–31 Mayıs")
  - Section headers use `TGSEyebrow` visual style (small red pill)

---

## P3 — Polish Backlog

| # | Item | Effort | Acceptance Criteria |
|---|------|--------|---------------------|
| P3-1 | Full accessibility pass (all custom components) | 10 hrs | WCAG 2.2 AA: all custom interactive elements have label + hint + traits |
| P3-2 | Dynamic Type support (body text minimum) | 8 hrs | App is usable at iOS Accessibility Large text (1.5× scale) without clipping |
| P3-3 | Proper 3-screen onboarding flow | 12 hrs | New user sees value prop → features → sign-in prompt before seeing directory grid |
| P3-4 | "Similar listings" in DirectoryDetailView | 6 hrs | 3 related listings shown at bottom of detail view (same directory + kanton) |
| P3-5 | Deep link / universal link support | 8 hrs | Opening `https://tgs-itt.ch/listing/{id}` opens the app at DirectoryDetailView |
| P3-6 | Inline map preview in EventDetailView | 6 hrs | Static MapKit snapshot shown before "Haritada Aç" button; tapping opens Maps |
| P3-7 | Forgot password flow (Phase 2 backend) | 5 hrs | "Parolamı Unuttum" link visible; taps show "E-posta gönderildi" message |
| P3-8 | Custom app icon (design-quality) | 4 hrs design + 1 hr export | Icon reviewed and approved by TGS brand owner; not AI-generated |
| P3-9 | Listing status badge in MyListingsView | 3 hrs | Pending/active/rejected shown as colour badge on each listing row |
| P3-10 | "Verified" or "Aktif Üye" badge on listings | 8 hrs | Listings with `paid_until > now` show a TGS badge in ListingRow and DetailView |

---

## Sprint Plan

### Sprint 1 (Days 1–3): Foundation + Ship-Ready Fixes
**Goal:** Clean up the worst friction before inviting external TestFlight testers.

- QW-1 through QW-10 (all quick wins, batched) — 2.5 hrs
- P0-1: Retry action in error dialogs — 2 hrs
- P0-2: FilterBar search debounce — 2 hrs
- P0-3: SubmitListingView required field indication — 2 hrs
- P1-5: App icon brand update (TGS red) — 1 hr
- **Sprint output:** Build 0.1.0 (5) uploaded to TestFlight; testers no longer see blue brand, bare errors, or silent disabled submit

### Sprint 2 (Days 4–8): Brand Coherence
**Goal:** Close the visual split between custom views and Form views; surface the brand consistently.

- P1-1: TGS red tint on all Form views — 1 hr
- P1-2: Welcome banner (first-run) — 3 hrs
- P1-3: Directory tile category CTA — 2 hrs
- P1-6: Type scale tokens in DesignSystem — 4 hrs
- P1-7: Corner radius + spacing tokens — 1 hr
- **Sprint output:** App has a coherent visual language across all screens; tokens are in place for further component work

### Sprint 3 (Days 9–14): Accessibility + Interaction Polish
**Goal:** Clear the WCAG 2.2 AA baseline; add first brand microinteractions.

- P1-4: Accessibility pass — priority surfaces — 3 hrs
- P2-2: Favourite toggle animation + haptic — 2 hrs
- P2-5: Error state inline component — 5 hrs
- P2-6: EventRow date grouping — 4 hrs
- **Sprint output:** VoiceOver navigable for primary JTBD #1 flow; error recovery is inline not modal; events have temporal structure

### Sprint 4 (Days 15–21): Core Flow Polish
**Goal:** Bring submission flow and loading experience up to Beta quality.

- P2-1: Skeleton loading screens — 6 hrs
- P2-3: TGS Form Component (design system refactor) — 16 hrs (pair programming recommended)
- **Sprint output:** Forms are visually consistent with the rest of the app; loading states communicate structure not just activity

### Sprint 5 (Days 22–28): Submission Flow Redesign
**Goal:** Make JTBD #3 (submit listing) competitive — this is the primary monetisation flow.

- P2-4: Multi-step SubmitListingView — 10 hrs
- P3-9: Listing status badge — 3 hrs
- **Sprint output:** Submitting a listing takes ≤ 5 minutes with clear progress; users know their submission status

---

## Design System Implications

The following fixes should be **promoted into DesignSystem.swift** (not patched locally):

| Fix | Token / Component | Impact |
|-----|-------------------|--------|
| Corner radii | `TGSRadius.card/inner/pill/field` | Propagates to all cards, pills, fields |
| Type scale | `TGSFont.display/title/headline/body/caption` | Replaces ad-hoc `size:` values everywhere |
| Amber colours (offline) | `Color.tgsAmber`, `Color.tgsAmberBg` | OfflineBanner + future warning states |
| Error colours | `Color.tgsError`, `Color.tgsErrorBg` | Inline error states, error messages |
| Success colours | `Color.tgsSuccess`, `Color.tgsSuccessBg` | PostSubmitView, confirmation states |
| Form section | `TGSFormSection` | Replaces `Form { Section {...} }` in 3 screens |
| Skeleton | `SkeletonRow`, `SkeletonCard` | Loading state for list and grid views |
| Error state | `ErrorStateView` | All data-loading screens |

Fixes that should be **patched locally** (not design-system):
- QW-3: Canton name on EventRow (data formatting, not a design pattern)
- QW-7: Emergency number sort order (content decision, not a design decision)
- QW-10: Hide SavedSearches (feature flag, not a design decision)

---

## Cross-Reference: Technical Audit Items

*(Pair with Project X-Ray when available)*

| UX Blocker | Likely Technical Root Cause | Note |
|---|---|---|
| Slow map open on first tap (DirectoryDetailView) | CLGeocoder network call blocks map open | Geocode on listing load, cache result in SwiftData; or use `MKLocalSearch` with address pre-fetched |
| No pagination in DirectoryListView | API returns `total` but iOS always fetches page 1 only | Backend pagination is implemented; iOS just needs `page` param + infinite scroll trigger |
| FilterBar fires on every keystroke | No debounce in `DirectoryListView.reload()` | P0-2 fixes the iOS side; confirm backend rate limits are set |
| No deep link support | No `onOpenURL` handler in `ITTRehberApp.swift` | Requires backend to resolve `/listing/{id}` → listing object; both sides needed |
| SubmitListingView image upload is slow | `APIClient.shared.uploadImage` is a blocking awaited call with no progress reporting | Add `URLSession.DataTask` with progress publisher; show upload progress bar |

---

*End of Action Plan*
