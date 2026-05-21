# ITT Rehber iOS — UI/UX Analysis Report
**Date:** 2026-05-21  
**Product:** ITT Rehber (TGS-ITT) — iOS 16+ SwiftUI  
**Build:** 0.1.0 (4) — Phase 1 foundation  
**Auditor:** Claude Opus 4.7 — full codebase review  

---

## 0 — Scope & Primary User

**Primary persona:** Swiss-Turkish community member (diaspora adult, 25–55), mixed digital literacy, device: iPhone (portrait, primary language Turkish).  
**Single most important task:** Find a Turkish-speaking professional in their Swiss canton — browse Sağlık/Hukuk/Finans directory → view detail → call or email.  
**Brand promise:** "Güvenilir rehber" — the warm, trusted guide for Turkish community life in Switzerland. Visual register must feel authoritative but approachable, never clinical.

**Top 3 primary jobs-to-be-done (JTBD):**
1. **Find professional** — RehberTab → tile → DirectoryListView (filter by kanton) → DirectoryDetailView → call/email
2. **Discover events** — EtkinliklerTab → list → EventDetailView → add reminder
3. **Submit listing** — DirectoryListView "+" → SubmitListingView → await approval

---

## 1 — UI/UX X-Ray (Status Scoring)

| #  | Dimension | Score | Justification | Critical Gap | Reference |
|----|-----------|-------|---------------|--------------|-----------|
| 1  | Visual Hierarchy & Layout | **6/10** | Post-redesign RehberTab has a clear hero + grid; detail views are well-organised. | All 10 directory tiles are visually identical (same red icon, same white card) — no category differentiation signals what's inside each tile. | `RehberTab.swift` |
| 2  | Typography System | **4/10** | Mix of explicit `.font(.system(size: N, weight:))` calls and semantic styles (`.headline`, `.subheadline`) with no central scale; brand font Inter (from website) absent entirely. | No type-scale tokens in DesignSystem.swift; font size inconsistency across screens (15/16/22/26/28pt all appear ad hoc). | `DesignSystem.swift`, `DirectoryListView.swift` |
| 3  | Color System & Contrast | **7/10** | Primary contrast (charcoal `#242C3B` on cream `#F8F4EF`) hits ~13:1 ✅; TGS Red on cream ~10:1 ✅; muted `#626C7A` on cream ~4.5:1 (just at WCAG AA floor). | `.tgsMuted` on `Color.tgsSurface` (beige) used in several places drops below 4.5:1 for small text; `OfflineBanner` foreground color (`Color(red:0.50,0.38,0.0)`) not in design system. | `DesignSystem.swift`, `DirectoryListView.swift` OfflineBanner |
| 4  | Component Consistency | **5/10** | Custom views (ActionButton, DetailRow, ListingRow, TGSEyebrow) are consistent. | Form-based screens (LoginView, SubmitListingView, SubmitEventView) use iOS system `Form` appearance — they render in UIKit inset-grouped style with no TGS colors, creating two visual worlds in the same app. | `LoginView.swift`, `SubmitListingView.swift` |
| 5  | Interaction & Microinteractions | **3/10** | All interactions are default iOS — push transitions, no haptics, bare `ProgressView` spinners, static favorite toggle. | Zero brand microinteractions: no haptic on add-to-favorites, no animation on tile tap, no success state transition after submit, no skeleton screens. | All views |
| 6  | Responsiveness & Cross-Device | **4/10** | Portrait iPhone works; `.preferredColorScheme(.light)` correctly enforced. | No Dynamic Type support (all explicit `size:` values); iPad renders as a stretched iPhone (orientations declared but layout not adapted); no landscape mode for iPhone even where it would be natural (EventDetailView with map). | `Info.plist`, all view files |
| 7  | Accessibility (WCAG 2.2 AA) | **4/10** | SwiftUI provides basic focus ring and VoiceOver defaults on standard controls; tab bar labels present. | Zero explicit `accessibilityLabel` / `accessibilityHint` on any custom view; `AsyncImage` has no alt text; `TGSEyebrow` uppercase text will be spell-read by VoiceOver; `ActionButton` tappable circles lack accessibility descriptions; all `DetailRow` values lack textSelection accessibility. | All custom components |
| 8  | IA & Navigation | **6/10** | 5-tab structure maps cleanly to major JTBD; nested NavigationStack is correct. | No deep link / universal link support (ShareLink generates a URL the app cannot open itself); no "related listings" from DirectoryDetailView; BilgiTab emergency numbers are unsorted by urgency; no progress indicator on multi-step SubmitListingView form. | `ITTRehberApp.swift`, `DirectoryDetailView.swift` |
| 9  | UX Writing & Microcopy | **5/10** | Turkish copy is natural throughout; confirmation messages are clear (PostSubmitView). | "İncele →" CTA on directory tiles is too vague; all error dialogs use bare "Hata" + "Tamam" with no retry action; LoginView footer exposes implementation detail ("gerçek Apple Developer Team gerektirir"); AraTab placeholder is descriptive not imperative ("bulun" not "hemen ara"); canton codes (ZH, BE) shown on EventRow without canton name. | `RehberTab.swift`, all alert calls, `LoginView.swift` |
| 10 | State Coverage | **6/10** | Loading, empty, and offline states exist in primary flows; PostSubmitView is thorough. | Error states are modals with no retry path; DirectoryDetailView has no skeleton/loading state when opening from cache; EventDetailView has no failed-state UI; `SubmitListingView` disables submit silently when required fields are missing — no inline hint. | `DirectoryDetailView.swift`, `EtkinliklerTab.swift` |
| 11 | Onboarding & First-Run | **2/10** | The eyebrow + title in RehberTab is functional but serves as the only orientation. | No onboarding: new users land cold on a 10-tile grid with no context about what the app does, which tile to tap first, or why they should create an account; no value-prop moment before the notification permission request in EventDetailView. | `RehberTab.swift`, `EtkinliklerTab.swift` |
| 12 | Brand Alignment | **6/10** | Main screens correctly apply TGS cream/charcoal/red language from the website redesign. | App icon is a solid blue box with "İTT" text (contradicts new TGS red brand); Form screens break visual continuity; no custom launch screen imagery; tab bar icons are generic SF Symbols (no custom treatment). | `AppIcon.appiconset`, `LoginView.swift`, `SubmitListingView.swift` |

**Weighted Overall UX Score: 5.1 / 10**

> **🟠 Functional (Alpha)** — The app has coherent navigation, real data flows, and a freshly applied brand language. The gaps are concentrated in accessibility, microinteractions, onboarding, and the visual split between custom views and system Form screens.

---

## 2 — Complexity Map (UX Surface Triage)

### 2.1 — 🟢 Simple Surfaces

| Surface | Polish (%) | Remaining Effort (hrs) | Note |
|---------|-----------|------------------------|------|
| ComingSoonView | 88% | 1 | Just needs brand illustration or better icon treatment |
| BilgiTab — Emergency Numbers section | 72% | 2 | Sort by urgency (112 first); add tap-to-call affordance more prominently |
| ContentPageView | 60% | 3 | Raw markdown dump; needs formatted headings, no loading skeleton |
| SubmitGateView | 82% | 1 | Good; just needs a secondary CTA pointing to ProfilTab |
| PostSubmitView | 75% | 2 | Good copy; needs a "track status" link or email confirmation note |
| SavedSearchesView | 60% | 3 | Empty state good; active state has no filter preview chips |
| ClaimableListingsView | 65% | 3 | Functional; no feedback after claiming other than row disappears |

### 2.2 — 🟡 Moderate Surfaces

| Surface | Polish (%) | Remaining Effort (hrs) | Note |
|---------|-----------|------------------------|------|
| RehberTab — hero + grid | 75% | 6 | Tiles need category-specific colour accent or subtitle; hero needs "first visit" context |
| DirectoryListView + FilterBar | 70% | 8 | No pagination UI; filter state persists but no active-filter count badge; search lacks debounce |
| AraTab (global search) | 65% | 7 | No recent searches; no suggested queries; result grouping works but needs visual hierarchy |
| EtkinliklerTab + EventRow | 72% | 5 | Date grouping (group by week) would help; kanton code needs full name display |
| ProfilTab — logged-in view | 65% | 5 | Destructive "Hesabımı Sil" is too close to "Çıkış yap"; no avatar/profile photo support |
| LoginView | 55% | 6 | Entire screen is system Form; no forgot-password flow; SIWA note is technical jargon |
| FavoritesView | 68% | 4 | Swipe-to-delete works; no "empty favourites" CTA to browse directory |
| MyListingsView | 62% | 5 | No status badge (pending/active/rejected); no edit action |

### 2.3 — 🔴 Hard Surfaces

| Surface | Polish (%) | Remaining Effort (hrs) | Note |
|---------|-----------|------------------------|------|
| DirectoryDetailView | 68% | 12 | Map open via CLGeocoder + MKMapItem works; but no inline map preview, no report flow UI, no "similar listings" |
| SubmitListingView | 58% | 14 | 15+ fields, no step-by-step guidance, image upload UX is raw, package picker is radio-list in Form |
| EventDetailView | 65% | 8 | Calendar integration is solid; but no share sheet for event, no "add to my calendar" success animation |

---

## 3 — UX Blockers & Proposed Solutions

### Blocker #1: No Onboarding — Cold Start Confusion
- **Category:** Information Architecture / UX Writing
- **Severity:** 🟠 Major — first-time users don't know what the app is or which tile to tap
- **Impact Area:** RehberTab, first-run experience
- **Evidence:** App opens directly to a 10-tile grid; no explanation of the app's purpose, no suggested first action, no account-creation incentive
- **Root Cause:** No onboarding flow was scoped for Phase 1
- **Solution A (Quick):** Add a dismissible banner card at the top of RehberTab on first launch: "TGS-ITT Rehber'e hoş geldiniz — İsviçre'deki Türk uzman ve etkinlik rehberi. Bir kategori seçin." (~2hrs, store `UserDefaults.hasSeenWelcome`)
- **Solution B (Permanent):** 3-screen onboarding sheet on first launch (value prop → key features → "Başla" CTA with optional sign-in prompt). Phase 2 scope.
- **Estimated Effort:** A: 2hrs / B: 12hrs

### Blocker #2: Form Screens Break TGS Visual Identity
- **Category:** Visual Design / Component Consistency
- **Severity:** 🟠 Major — LoginView, SubmitListingView, SubmitEventView render in iOS system appearance (grey inset cells, blue tint)
- **Impact Area:** LoginView, SubmitListingView, SubmitEventView
- **Evidence:** Every `Form { Section { ... } }` uses UIKit table appearance — no cream background, no TGS red tint in cells
- **Root Cause:** SwiftUI `Form` uses system appearance and cannot be fully overridden without replacing it entirely with scroll + VStack
- **Solution A (Quick):** Apply `.tint(Color.tgsRed)` and `.scrollContentBackground(.hidden)` + `.background(Color.tgsCream)` to all Forms (~1hr); this fixes button/toggle tint without a full rewrite
- **Solution B (Permanent):** Replace `Form` with `ScrollView + LazyVStack` using custom `TGSFormSection` component that renders white inner cards. Enables full design control.
- **Estimated Effort:** A: 1hr / B: 16hrs

### Blocker #3: Error States Have No Recovery Path
- **Category:** Interaction Design / State Coverage
- **Severity:** 🟠 Major — every API error shows a bare "Hata / Tamam" dialog; dismissing it leaves the user on an empty screen
- **Impact Area:** All data-loading views (DirectoryListView, AraTab, EtkinliklerTab, DirectoryDetailView)
- **Evidence:** `.alert("Hata", isPresented: .constant(error != nil)) { Button("Tamam") { error = nil } }` — dismiss only, no retry
- **Root Cause:** Error handling was implemented as minimum viable; retry logic was not considered
- **Solution A (Quick):** Add a "Tekrar dene" button alongside "Tamam" in all error alerts; the action calls `load()` again (~2hrs across all views)
- **Solution B (Permanent):** Create a reusable `ErrorStateView` component (icon + message + retry button) that replaces the list/grid when in error state — inline rather than modal
- **Estimated Effort:** A: 2hrs / B: 5hrs

### Blocker #4: Zero Accessibility Annotations
- **Category:** Accessibility (WCAG 2.2 AA)
- **Severity:** 🟠 Major — Swiss market increasingly enforces accessibility requirements; VoiceOver users get zero context from custom components
- **Impact Area:** All custom views — ActionButton, DetailRow, ListingRow, TGSEyebrow, DirectoryTile
- **Evidence:** No single `accessibilityLabel`, `accessibilityHint`, or `accessibilityElement` modifier in the entire codebase
- **Root Cause:** Not scoped in Phase 1; SwiftUI defaults only cover standard controls
- **Solution A (Quick):** Add `accessibilityLabel` to the 5 highest-priority interactive elements: ActionButton (call/email/maps/web), favorite toggle, and DirectoryDetailView AsyncImage (~3hrs)
- **Solution B (Permanent):** Systematic a11y pass: all custom components get `.accessibilityElement(children:)`, `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityTraits`; add `AccessibilityTests` to the test target
- **Estimated Effort:** A: 3hrs / B: 10hrs

### Blocker #5: FilterBar Triggers API Call on Every Keystroke
- **Category:** Interaction Design / Performance Perception
- **Severity:** 🟠 Major — each character typed fires a network request; on slow connections this causes a cascade of loading states and can produce out-of-order results
- **Impact Area:** DirectoryListView → FilterBar → `reload()`
- **Evidence:** `FilterBar.onChange` calls `onChange` closure immediately on text change; `DirectoryListView.reload()` immediately fires `APIClient.shared.listings(...)` with no debounce
- **Root Cause:** No debounce logic was implemented
- **Solution A (Quick):** Add a 400ms debounce using `Task.sleep` in `FilterBar` text-change handler (~2hrs)
- **Solution B (Permanent):** Add a shared `debounce()` extension on `Task` / use `Combine` publisher with `.debounce(for:)` to drive the search; unify with AraTab's search
- **Estimated Effort:** A: 2hrs / B: 4hrs

### Blocker #6: App Icon Contradicts New Brand Identity
- **Category:** Visual Design / Brand Alignment
- **Severity:** 🟡 Minor (pre-launch) → 🟠 Major (post-launch) — the icon on the home screen is the first brand impression
- **Impact Area:** Home screen, App Store listing, Spotlight search
- **Evidence:** All icon sizes are solid blue `#1A5695` with white "İTT" text — blue was the old brand colour, now TGS Red `#B82030` is primary
- **Root Cause:** Icons were generated programmatically in Phase 1 as placeholder; brand wasn't finalised then
- **Solution A (Quick):** Regenerate all 15 icon sizes with TGS red background `#B82030` + "TGS" or a simple crescent/globe symbol in white (~1hr with existing Python script)
- **Solution B (Permanent):** Commission a proper icon from a designer: crescent/star referencing Turkish identity within a Swiss-style clean frame; produce at 1024×1024 source
- **Estimated Effort:** A: 1hr / B: 4hrs (design) + 1hr (export + wire)

### Blocker #7: "İncele →" CTA Doesn't Communicate Value
- **Category:** UX Writing
- **Severity:** 🟡 Minor
- **Impact Area:** RehberTab — DirectoryTile for all 10 categories
- **Evidence:** "İncele" means "inspect/examine" — appropriate for a product but too vague for a directory tile; user doesn't know how many listings are inside or what they'll find
- **Root Cause:** Placeholder copy from initial design; no listing count available on the tile (counts aren't fetched for the grid view)
- **Solution A (Quick):** Change "İncele" to the plural of the category noun: "Uzmanları Gör", "Avukatları Gör", "Etkinlikleri Gör" — using `directory.cta` computed property (~1hr)
- **Solution B (Permanent):** Fetch listing counts per directory on RehberTab load and display "14 uzman" as a subtitle on each tile
- **Estimated Effort:** A: 1hr / B: 4hrs

### Blocker #8: LoginView Footer Exposes Implementation Detail
- **Category:** UX Writing
- **Severity:** 🟡 Minor
- **Impact Area:** LoginView — SIWA section footer
- **Evidence:** Text reads: "Apple ile Giriş için Apple Developer ekip kimliği yapılandırılmalı. Şimdilik e-posta ile devam edin." — users should not read about developer configuration
- **Root Cause:** Dev note was pasted as user-facing copy
- **Solution A (Quick):** Replace with: "Apple ile Giriş yakında aktif olacak. Şimdilik e-posta ile devam edebilirsiniz." (~5 minutes)
- **Estimated Effort:** A: 5min / B: N/A

### Blocker #9: Dynamic Type Not Supported
- **Category:** Accessibility / Responsiveness
- **Severity:** 🟠 Major — ~20% of iOS users have accessibility text sizes enabled; this audience skews older, which overlaps with the Turkish diaspora community
- **Impact Area:** All views with explicit `font(.system(size: N))`
- **Evidence:** `DesignSystem.swift` and all view files use `size:` literal values; `.dynamicTypeSize` is never set; no `@ScaledMetric` usage
- **Root Cause:** Not scoped in Phase 1; explicit sizes were used for pixel-perfect TGS brand match
- **Solution A (Quick):** Audit and replace the 10 most-used explicit font sizes with semantic equivalents (`.body`, `.headline`, `.subheadline`, `.caption`) where semantically correct. Cover at least all body-text sizes.
- **Solution B (Permanent):** Add `TGSFont` namespace to `DesignSystem.swift` with `@ScaledMetric` constants for decorative display sizes; use `.font(.custom("InterOrSystemFont", size: scaledSize, relativeTo: .body))` pattern
- **Estimated Effort:** A: 3hrs / B: 8hrs

---

## 4 — Anti-Pattern & Friction Detection

### 🔴 Accessibility Gaps
- **All custom interactive views → No accessibilityLabel** → Add `.accessibilityLabel` to ActionButton, DirectoryTile, ListingRow, EventRow
- **AsyncImage in DirectoryDetailView + EventDetailView → No alt text** → Add `.accessibilityLabel(listing.name)` to image container
- **TGSEyebrow ("İSVİÇRE'DE TÜRK TOPLULUĞU") → VoiceOver spells it letter-by-letter due to ALL-CAPS** → Use `.accessibilityLabel("İsviçre'de Türk Topluluğu")` override
- **`.tgsMuted` on `.tgsSurface` background → contrast ~3.8:1, below 4.5:1 AA for small text** → Use `.tgsCharcoal` or increase `.tgsMuted` brightness; or don't use muted text on surface background for informational content

### 🔴 Missing Feedback
- **Favourite toggle → No haptic, no animation on state change** → Add `UIImpactFeedbackGenerator.impactOccurred()` on toggle; animate the star icon with `.scaleEffect` + `.spring()`
- **"Favorilerden çıkar" → Instant removal with no undo** → Add 2-second undo toast or `.onDelete` swipe with delay
- **DirectoryListView pull-to-refresh → No visual confirmation that data updated** → Show a brief "Güncellendi" toast (iOS 16+ overlay)
- **SubmitListingView submit disabled → No tooltip explaining why** → Show validation summary above the submit button listing unfulfilled required fields

### 🟠 Inconsistent Patterns
- **Button styles: two worlds** → Main screens use `.borderedProminent` (TGS red from tint) + custom TGS card buttons; Forms use default system `.bordered` → standardise by setting `.tint(Color.tgsRed)` on all `Form` views
- **Corner radii: 24pt (tgsCard) vs 16pt (tgsInnerCard) vs 14pt (favourite button bg) vs 12pt (FilterBar field) vs 10pt (old AraTab fields)** → Consolidate to 3 radii: 24/16/12 as tokens
- **Loading states: spinner only** → Some screens show `ProgressView("Yükleniyor…")` full-screen, others show it inline; no skeleton screens anywhere
- **Section headers: inconsistent capitalisation** → `SubmitListingView` uses sentence-case section titles; `SubmitEventView` uses sentence-case; `ProfilTab` uses sentence case; `AraTab` result section headers are all-lowercase — standardise

### 🟠 Cognitive Overload
- **SubmitListingView → 15+ form fields on a single scroll** → No step-based structure (Step 1: Basics, Step 2: Contact, Step 3: Package); users don't know how long the form is
- **RehberTab → 10 tiles at once with no visual hierarchy or suggested starting point** → Consider a "Önerilen: Sağlık" or "En çok ziyaret edilen" cluster for first-time users

### 🟡 Navigation Drift
- **DirectoryDetailView → No "Benzer uzmanlar" or back-to-list context** → After viewing a listing, there's no nudge to browse more; users must tap Back manually
- **SubmitListingView → No progress indicator** → 15+ fields with no "Adım 2/3" or visual completion meter
- **ProfilTab → FavoritesView → DirectoryDetailView → cannot reach AraTab directly** → Deep link dead-end; no shortcut to search from detail view

### 🟡 Form Friction
- **LoginView → No "Parolamı Unuttum" link** → Swiss users will expect this; even if the feature is Phase 2, the link should be visible (disabled, with "Yakında" tooltip)
- **FilterBar → No active filter badge on the kanton button** → When ZH is selected, the button changes text but the visual weight doesn't indicate "filter active"; a filled pill vs outline pill distinction would help
- **SubmitListingView → Required image not marked** → The submit button silently stays disabled until photo is uploaded; no "* zorunlu alan" indicator near the photo picker

### 🟡 Copy Issues
- **LoginView SIWA footer → Implementation detail exposed** → See Blocker #8
- **EventRow → Canton code only** → "ZH" instead of "Zürich" for users unfamiliar with Swiss cantons → Show `Kanton.all.first(where: { $0.code == event.kanton })?.nameTR ?? event.kanton`
- **AraTab placeholder → Passive** → "Tüm rehberlerde tek aramada bulun" → "Tüm rehberlerde ara…"
- **Empty error alert body → "Tamam" as sole action** → Replace with "Tekrar Dene" primary + "Kapat" secondary

### 🟡 Visual Debt
- **OfflineBanner → Hardcoded non-token colors** → `Color(red: 0.50, 0.38, 0.0)` and `Color(red: 1.0, 0.93, 0.64)` are not in DesignSystem.swift → add `tgsAmber` and `tgsAmberBg` tokens
- **ListingRow initials avatar → `Color.tgsSurface` background with `Color.tgsMuted` text** → contrast ~3.8:1 for "ZK" etc. — use `Color.tgsBorder` or bump initials weight
- **DirectoryTile minHeight 148pt** → On smaller iPhones (SE, mini), 2-column grid may feel cramped; test at 375pt width

---

## 5 — User Journey / Mission Drift Analysis

### JTBD #1: Find a Turkish-speaking professional in my canton

**Intended flow:** Open → RehberTab → tap relevant tile → filter by kanton → browse results → tap listing → call/email  
**Actual flow:** Same, but:
- User must know which of the 10 tiles maps to their need (no descriptions on tiles)
- FilterBar is visible but kanton selection is a full-screen Menu, not a chip strip — extra tap
- Results list has no sorting (by name only) — no "closest to me" or "verified" signal
- Listing detail has good action buttons, but "Harita" geocodes on-the-fly (slow on first tap)

**JTBD alignment:** ~70% — core flow works; UX friction on tile disambiguation and search relevance

### JTBD #2: Discover upcoming events near me

**Intended flow:** EtkinliklerTab → see list → tap event → add reminder  
**Actual flow:** Same, but:
- Events are not grouped by week/month — a flat undifferentiated list
- EventRow shows "ZH" not "Zürich" — canton filter is an obscure dropdown
- No "today's events" prioritisation
- EventDetailView reminder sets correctly but no visual confirmation animation

**JTBD alignment:** ~65% — functional but lacks date context and discovery aids

### JTBD #3: Submit my business/practice for listing

**Intended flow:** DirectoryListView "+" tap → fill form → submit → wait for approval  
**Actual flow:** Same, but:
- Requires login first → SubmitGateView (not telegraphed — user taps "+" with no warning)
- If not logged in: sees SubmitGateView → must go to ProfilTab → login → navigate back to directory → tap "+" again → 6 extra steps
- SubmitListingView has 15+ fields: overwhelming
- Image upload is required but not visually indicated as blocking

**JTBD alignment:** ~50% — significant friction for a key monetisation flow

### Scope Creep Assessment

- **ClaimableListingsView** — Phase 2 v1-migration feature showing up in Phase 1 UI for most users who have no v1 listings; safe to hide behind feature flag
- **SavedSearchesView + MyListingsView** — Listed in ProfilTab but these features have no UI surface in the primary flow to actually save a search; "Kayıtlı Aramalar" is a dead end until AraTab gets a "Save Search" button

### Persona-Register Check

- **Visual register:** The TGS design language (cream, editorial cards, charcoal) is correct for a trusted community authority — neither corporate-cold nor consumer-playful. ✅
- **Density:** Current density is appropriate for browsing (sparse list view); slightly too dense in SubmitListingView for a potentially nervous first-time user
- **Tone:** Turkish copy is natural and warm; the technical SIWA note and developer jargon are anomalies
- **Context mismatch:** Destructive action ("Hesabımı Sil") placement is casual — it's near everyday nav items; should require more friction (confirmation step + deliberate navigation)

### Realignment Recommendations

1. **Remove from primary nav:** "Kayıtlı aramalar" in ProfilTab (it's a dead end in Phase 1)
2. **Defer to Phase 2:** v1 claim listings notification in ProfilTab (hide with `featureFlag.claimEnabled`)
3. **Add to Phase 1 before launch:** One-line disambiguation subtitles on DirectoryTile; "Parolamı Unuttum" placeholder; retry action in error dialogs; dynamic type for body text
4. **Persona-tone corrections:** Replace dev-note SIWA copy; replace "İncele" with verb + noun CTA per category

---

*End of Analysis Report*
