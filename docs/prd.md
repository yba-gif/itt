**ITT-Rehber 2.0**

Product Requirements Document

*A directory app for the Turkish community in Switzerland*

  -------------------- --------------------------------------------------
  **Document version** v2.0 --- Stakeholder-approved draft

  **Date**             2026-05-03

  **Owner**            Roar (Yusuf Berkan Altun)

  **Engagement**       Full rebuild of ITT-Rehber iOS app from existing
                       v1

  **Predecessor**      ITT-Rehber v1, App Store ID 6742571691, published
                       by Fatih Karaoglu

  **Disposition of     Acquired outright by Roar (IP, App Store transfer
  v1**                 not in scope --- fresh listing under Roar)

  **Status**           Approved for engineering hand-off
  -------------------- --------------------------------------------------

**1. Executive Summary**

ITT-Rehber is a Turkish-language directory app for the Turkish community
in Switzerland. The current iOS app (v1) is a thin WebView wrapper
around a network of Google Apps Script web pages backed by a single
Google Sheet. It works, but it is architecturally fragile, has zero
engagement features, exposes a Google API key in client-side code, and
has zero ratings on the App Store after launch.

This document specifies a full rebuild as a native iOS application with
a real backend, a paid listing model with manual moderation, and the
engagement features (search, favorites, push notifications, offline
access) that v1 lacks. The product retains every feature of v1, fixes
its known bugs, and adds the monetization and trust infrastructure
needed to operate as a sustainable business.

**1.1 What ships in v2**

- Native iOS app (Swift / SwiftUI), iOS 16+, with offline support for
  static content

- Real backend (PostgreSQL + FastAPI) replacing Google Sheets as the
  data layer

- Ten directories --- Health, Legal, Business, Finance, Translation,
  Profession/Apprenticeship, Schools, Mosques, Alumni, Tutoring --- plus
  an Events feed

- Free-text search across all directories, in addition to existing
  dropdown filters

- Optional user accounts with favorites and saved searches; anonymous
  browsing remains the default

- Paid service-provider listings (60 / 100 / 180 CHF for 3 / 6 / 12
  months, with the first month free for all listings)

- Payment via TWINT and bank transfer with auto-generated PDF invoices
  --- no Apple In-App Purchase

- Manual moderation queue with admin web panel --- every new and edited
  listing is human-reviewed before going live

- Push notifications for new events and editorial updates

- Welcome guide and emergency numbers available offline

- Soft-launch sunset of v1: deprecation banner pointing v1 users to v2
  via the App Store

**1.2 What does not ship in v2**

- Android --- out of scope for this engagement

- Multi-language UI --- Turkish only at launch; v1 falsely advertised 16
  languages and the App Store metadata will be corrected

- In-app messaging between users and providers --- providers are
  contacted via email/phone/website links, as in v1

- In-app payment for end users --- only providers pay, and they pay via
  TWINT or bank transfer outside the app surface

- Reviews and ratings of providers --- explicitly excluded from the
  product (not deferred, removed)

- Trust badges or \"Verified\" indicators on listings --- explicitly
  excluded

- Premium/featured listing tiers --- single flat-fee model only

- Anonymous-user analytics and telemetry --- explicitly not collected

**2. Goals & Non-Goals**

**2.1 Product goals**

The rebuild should deliver a directory that the Turkish community in
Switzerland can rely on as the default first-search resource. Three
concrete goals follow from that.

- **Goal 1: Trustworthy directory.** Every listing visible in the app
  has been manually reviewed. The user never sees a fake lawyer, a
  closed restaurant, or a phone number that goes to a personal mobile of
  someone unrelated. This is the differentiation versus generic Google
  search.

- **Goal 2: Sustainable revenue.** Paid listings generate enough revenue
  to cover infrastructure, moderation labor, and an annual editorial
  budget (Welcome Guide updates, consulate liaison content). Target: 100
  paid listings within 6 months of launch.

- **Goal 3: Engagement.** Move from zero-engagement (v1 has zero App
  Store ratings) to a measurable returning-user base. Target: 30% D7
  retention, 10% D30 retention by month 6 (measured for logged-in users
  only --- see analytics policy in §7.4).

**2.2 Non-goals**

- **Becoming a transactional marketplace.** Booking, payments to
  providers, escrow --- none of this. The app is a directory, not a
  marketplace. Providers are contacted via existing channels (email,
  phone, website).

- **Replacing official Swiss government services.** The app does not
  file paperwork, replace ch.ch, or offer legal advice. It points users
  to the right professional or institution.

- **Pan-European or pan-diaspora reach.** Scoped to Switzerland and the
  Turkish-speaking community there. Geographic and linguistic expansion
  are deferred.

- **Building a tracking and analytics infrastructure.** Privacy is a
  product principle. Anonymous-user telemetry is explicitly not
  collected --- no Plausible, no PostHog tracking of unauthenticated
  sessions.

**2.3 Success metrics**

Note on measurement: since anonymous-user telemetry is not collected,
the metrics below are derived from authenticated-user activity,
server-side request volumes, and App Store Connect data. This is a
deliberate design constraint, not a gap.

  ------------------------------------------------------------------------
  **Metric**         **Target by      **Measurement source**
                     month 6**        
  ------------------ ---------------- ------------------------------------
  Authenticated MAU  1,500+           Backend session telemetry (logged-in
                                      users only)

  App downloads      5,000+           App Store Connect

  Paid active        100+             Admin dashboard
  listings                            

  Authenticated D7 / 30% / 10%        Cohort analysis on logged-in users
  D30 retention                       

  App Store rating   ≥ 4.3 (≥ 50      App Store Connect
                     reviews)         

  Submission to      \< 24 hours      Moderation queue logs
  publish lead time  (P50)            

  Crash-free session ≥ 99.5%          Crash reporting (Sentry)
  rate                                
  ------------------------------------------------------------------------

**3. Users & Personas**

**3.1 Primary persona --- Aylin (newcomer)**

32, software engineer who relocated from Istanbul to Zürich three months
ago on an L-permit. Speaks intermediate German and fluent English.
Looking for: a Turkish-speaking pediatrician, a tax advisor familiar
with the bilateral CH-TR agreement, a translator for a notary
appointment, a Saturday Turkish school for her 6-year-old. Has installed
the app after a recommendation in a Telegram group. Will use it 2--3
times in the first month, then probably less.

What she needs: confidence that the listings are real and current.
Filtering by kanton. The ability to call or email a provider in two
taps. Offline access to emergency numbers because she had a panic moment
when her phone had no signal in a Migros parking lot.

**3.2 Secondary persona --- Mehmet (provider)**

45, has lived in Basel for 18 years, owns a small accounting firm. Knows
the community well, gets asked for recommendations constantly. He is a
candidate paid-lister: he wants his accounting firm to appear when
newcomers search \"muhasebe Basel\". He will pay 100 CHF for 6 months
without negotiating if the submission flow takes less than 10 minutes.

What he needs: a frictionless submission flow, a clear preview of what
his listing will look like, a PDF invoice he can expense, and the
ability to update his listing (new phone number, new address) without
re-submitting from scratch.

**3.3 Tertiary persona --- Roar (admin / editor)**

The operator of the app. Reviews submissions in the admin web panel,
gets a daily email digest of pending items. Writes all editorial content
personally --- Welcome Guide updates, consulate news, push notification
copy. Sends push notifications when there is news from the consulate or
a major community event.

What the admin panel must enable: one-tap approve/reject with reason
codes, bulk operations (approve 5 mosque listings at once), audit trail
of who edited what, CSV export of every listing for backup, and a
content editor for Welcome Guide / Consulate Info / Privacy / Terms
pages.

**4. Information Architecture**

The app has four top-level surfaces, surfaced via a tab bar. This is a
deliberate simplification of v1, which had a sprawling navigation menu
with no clear hierarchy.

**4.1 Top-level navigation**

  --------------------------------------------------------------------------
  **Tab**       **Purpose**      **Contains**
  ------------- ---------------- -------------------------------------------
  Rehber        Browse the 10    Health, Legal, Business, Finance,
                directories      Translation, Profession, Schools, Mosques,
                                 Alumni, Tutoring

  Etkinlikler   Community events Upcoming events list, event detail, \"Add
                feed             event\" community submission form

  Bilgi         Reference        Welcome Guide, Emergency Numbers, Consulate
                content          Info, Privacy, Terms, About

  Profil        User account     Login/signup (optional), Favorites, Saved
                                 searches, Settings, Listing management (if
                                 user is a provider)
  --------------------------------------------------------------------------

**4.2 Directory hierarchy**

Each of the ten directories shares the same internal structure: a list
view with filters, a detail view, and (for service providers) an \'Add
my service\' submission flow. Schemas differ --- see Section 6 for the
data model.

  ----------------------------------------------------------------------------------
  **Directory**   **TR       **Filters**        **Notes**
                  label**                       
  --------------- ---------- ------------------ ------------------------------------
  Health          Sağlık     Kanton, Alan       Doctors, dentists, psychologists
                             (specialty)        

  Legal           Hukuk      Kanton, Alan       Lawyers, notaries, immigration
                                                consultants

  Business        İşletme    Kanton, Kategori   Restaurants, markets, retail,
                                                services

  Finance         Sigorta /  Kanton, Kategori   Insurance brokers, tax advisors,
                  Finans                        accountants

  Translation     Tercüme    Kanton, Dil,       Sworn and informal translators
                             Yöntem             

  Profession      Meslek     Kanton, Kategori,  Apprenticeship and Schnupperlehre
                  (Lehre)    Meslek             opportunities

  Schools         Okullar    Kanton, Gün        Turkish-language Saturday/Sunday
                                                schools

  Mosques         Diyanet    Kanton             Diyanet-affiliated mosques
                  Camiler                       

  Alumni          Mezunlar   Üniversite         Turkish alumni network from Swiss
                                                universities

  Tutoring        Destek     Bölge, Konu,       Private tutoring providers
                  Dersi      Seviye, Yöntem     
  ----------------------------------------------------------------------------------

**5. Feature Specification**

**5.1 Directory list view**

Each directory presents entries as a vertically scrollable list. The
screen is composed of three regions: a filter bar at the top, a result
count, and the result list.

**Filter bar**

- Free-text search field at the top --- searches across name,
  specialty/category, and address. New in v2.

- Dropdown filters for the directory-specific dimensions (Kanton, Alan,
  Kategori, etc. --- see §4.2). Filters apply in AND combination.

- Active filters render as removable pill chips below the dropdowns;
  one-tap to clear an individual filter.

- \"Reset filters\" link clears all filters at once.

**Result list**

- Each row shows: provider name (bold), kanton(s), primary
  category/specialty, and a small mandatory logo/photo. No badges or
  \'Sponsored\' labels --- paid and unpaid listings are visually
  identical.

- Sort: alphabetical within kanton group. No paid-tier promotion or
  featured placement (per single-flat-fee model).

- Empty state: \"Aradığınız kriterlere uygun veri bulunamadı\" with a
  CTA to clear filters or contact support.

- List supports pull-to-refresh and pagination (50 results per page).

**Result count**

- \"X uzman bulundu\" displayed above the list and updated reactively as
  filters change.

**5.2 Directory detail view**

Tapping a list entry opens the detail view. Layout is a card-style
scrollable view with action buttons.

**Sections (top to bottom)**

- Hero: provider name, mandatory logo/photo, kanton(s), primary category

- Action buttons row: **Call** (if phone shown), **Email** (if email
  shown), **Open in Maps**, **Visit Website** --- each opens the native
  iOS handler

- Details: full address, languages spoken (where applicable), hours
  (where applicable). Contact methods (email and phone) are shown only
  for fields the provider has chosen to make public.

- Description: free-text field providers can fill in (max 500 chars)

- Last updated timestamp (small, muted text --- provides freshness
  signal without being a trust badge)

- \"Add to Favorites\" toggle (requires login)

- \"Report this listing\" link → opens moderation report flow (requires
  login, see §5.9)

- \"Share\" --- system share sheet, generates a deep link back into the
  app

**Contact-method visibility (per provider preference)**

In the submission flow, the provider chooses whether email and phone are
shown publicly. Address and website are always shown if provided. This
gives providers control over which channels they handle support on,
while keeping the directory\'s core utility intact.

**Maps integration**

v1 uses a Google Maps search URL. v2 uses Apple Maps via MKMapItem and
falls back to Google Maps URL if the user has set a non-Apple-Maps
default. The address is also displayed in-line above the map button so
it can be copied.

**5.3 Events feed**

+-----------------------------------------------------------------------+
| **⚠️ Bug fix from v1**                                                |
|                                                                       |
| v1 has a \"Gelecekteki Etkinlikler\" (Future Events) screen that does |
| NOT actually filter by date --- it shows every event in the sheet,    |
| including events from the past. v2 fixes this: the events feed shows  |
| only events with a date ≥ today. A separate \"Geçmiş Etkinlikler\"    |
| sub-tab is available on the same screen for browsing past events.     |
+-----------------------------------------------------------------------+

- Events ordered chronologically (soonest first).

- Each event card shows: title, date and time, location (kanton +
  venue), poster image if provided.

- Tapping a card opens an event detail view with full description,
  address (Maps button), and an \"Add to Calendar\" action (iOS native
  EventKit).

- Filter by kanton only. No search bar in the events feed (events are
  typically few enough that browsing suffices).

- \"Hatırlatma kur\" button schedules a local notification 24 hours
  before the event.

**Community event submission**

Anyone can submit events --- no account required. Submission is
moderated before going live (same queue as listings).

- Fields: name, date, time, location, kanton, optional poster image,
  contact email of submitter (private --- used by moderators only).

- Free for community submissions. Events are not part of the paid
  listing model.

- Submission is queued for admin review; submitter receives a
  confirmation email immediately and an approval/rejection email when
  reviewed.

**5.4 Welcome Guide & static content**

The \'Bilgi\' tab houses static content that doesn\'t fit the directory
model. All static content is downloaded once and cached locally, so it
works offline. All content is authored by Roar personally.

  ------------------------------------------------------------------------
  **Page**               **Source**         **Editable   **Offline?**
                                            by admin?**  
  ---------------------- ------------------ ------------ -----------------
  Welcome to Switzerland CMS-managed,       Yes          Yes
  (Hoş Geldiniz)         written by Roar                 

  Emergency Numbers      CMS with hardcoded Yes          Yes --- critical
  (Acil Durumlar)        fallback                        

  Turkish Consulates in  CMS-managed        Yes          Yes
  CH                                                     

  Privacy Policy         CMS-managed        Yes          Yes

  Terms of Service       CMS-managed        Yes          Yes

  About / Künye          CMS-managed        Yes          Yes
  ------------------------------------------------------------------------

**Welcome Guide content (v1 carryover)**

v1\'s Tab 4 contains 11 sections of orientation content (registration,
language, work, housing, transportation, banking, education, culture,
Turkish community, emergency, Turkey connections). v2 keeps the same
sections and content as a starting point, restructured into a navigable
list with anchor links and reading-progress markers. Roar will update
content as needed via the admin panel.

**5.5 Search**

v1 has zero free-text search. v2 makes search a primary feature, not a
feature of individual directories.

- Global search icon in the tab bar (or as a search field at the top of
  the Rehber tab).

- Searches across all directories simultaneously. Results grouped by
  directory type.

- Search matches: name, category/specialty, kanton name, free-text
  description.

- Implementation: PostgreSQL full-text search with Turkish stemming
  (unaccent + Turkish dictionary). For v1 scale (\< 10K rows), this is
  sufficient --- no Elasticsearch needed.

- Recent searches stored locally; user can clear them.

- Saved searches (logged-in users only): name a search and get notified
  when new matching listings are published.

- No search analytics on anonymous users --- popular-search insights
  come from logged-in users only.

**5.6 User accounts (optional)**

Anonymous browsing is the default. The app prompts for account creation
only when the user attempts to: favorite a listing, save a search,
submit a listing, or report a listing. Sign-in is via Sign in with Apple
(mandatory by Apple guidelines if any other social login is offered) and
email/password.

- Sign in with Apple --- primary method (one tap, no password).

- Email + password --- secondary, with no email verification step. Admin
  moderation catches fakes during the listing-submission flow, where
  impersonation matters; for plain user accounts, email verification is
  friction without proportional value.

- No social logins beyond Apple in v1 (Google/Facebook explicitly
  excluded --- adds compliance burden without proportional value).

- Account deletion is self-serve from Settings → Hesabımı Sil. Required
  by App Store guideline 5.1.1(v).

- Profile holds: display name, email, language preference (TR for now),
  notification preferences, list of favorites, list of saved searches,
  list of listings the user owns (one user can own multiple listings).

**Account deletion + active listings**

If a user with active paid listings deletes their account, the listings
remain active until their paid_until date and ownership is anonymized
(owner_id set to NULL, contact email replaced with the listing\'s public
email). This honors the paid term while complying with FADP/GDPR
right-to-erasure for the user\'s account itself. No refunds (per refund
policy in §5.7).

**5.7 Paid listing model & submission flow**

+-----------------------------------------------------------------------+
| **💰 Pricing (locked)**                                               |
|                                                                       |
| • 3 months --- **60 CHF**                                             |
|                                                                       |
| • 6 months --- **100 CHF**                                            |
|                                                                       |
| • 12 months --- **180 CHF**                                           |
|                                                                       |
| **• First month free for all listings (new and existing v1 listings   |
| migrating in)**                                                       |
|                                                                       |
| **• Single listing covers multiple directories at no extra cost       |
| (e.g., a lawyer who also offers translation)**                        |
|                                                                       |
| **• Single listing covers multiple kantons at no extra cost**         |
|                                                                       |
| **• Multi-location businesses pay separately per location (each       |
| location = one listing)**                                             |
|                                                                       |
| **• No refunds --- listings are non-refundable services. Stated       |
| explicitly in ToS and at submission time.**                           |
+-----------------------------------------------------------------------+

**Submission flow (provider perspective)**

- **Step 1:** From any directory, tap \"Hizmetinizi Ekleyin\".
  Authenticated user required.

- **Step 2:** Choose primary directory and category. Optionally add this
  listing to additional directories at no extra cost (multi-directory
  checkboxes shown after primary is selected).

- **Step 3:** Fill in: name, contact person, kanton(s --- multi-select),
  category, specialty/profession, address, phone, email, website,
  description (max 500 chars), mandatory logo/photo upload. For email
  and phone, provider chooses per-field whether to show publicly.

- **Step 4:** Choose package: 3 months / 6 months / 12 months. The first
  month is free for all new listings.

- **Step 5:** Preview screen --- exactly how the listing will appear in
  the app. Edit or confirm.

- **Step 6:** Choose payment method: TWINT or bank transfer. Both result
  in a generated PDF invoice (sent to the email on file). Payment
  instructions are shown on screen and in the invoice email.

- **Step 7:** Submission enters moderation queue. User receives
  confirmation email: \'Your submission is under review and will go live
  within 24 hours.\'

- **Step 8:** Listing goes live AFTER admin approval. The first month is
  free regardless of payment status; payment must be received before the
  second month begins, otherwise the listing is suspended.

**Invoice generation**

- Server-side PDF generation using a standard template (ITT branding,
  MwSt info if applicable, payment instructions for TWINT QR and IBAN
  bank transfer).

- Invoice number format: ITT-YYYY-NNNNN (sequential, year-reset).

- Sent automatically to the email on file at submission time, and
  accessible from Profile → My Listings → \[Listing\] → Invoice.

**Payment reconciliation**

- Admin panel has a \"Pending Payment\" queue showing listings
  approved-but-unpaid past their free month.

- Admin manually marks payment received once funds are confirmed in the
  bank account / TWINT app.

- Future enhancement (out of v1 scope): TWINT API integration for
  auto-reconciliation. Listed in §11.

**Renewal**

- 30 days before expiry, owner receives a renewal email and an in-app
  banner notification.

- Renewal flow is one-tap if the listing has not changed: select
  package, generate new invoice.

- Expired listings become hidden from public view but are not deleted;
  owner can renew within 90 days to restore.

+-----------------------------------------------------------------------+
| **🍎 App Store compliance note**                                      |
|                                                                       |
| Apple\'s Guideline 3.1.1 requires In-App Purchase for digital content |
| consumed in the app. Business directory listings are                  |
| advertising/service-listing fees, which fall under 3.1.3(b)           |
| (\"reader\" apps and physical-world services) and are NOT required to |
| use IAP. We will document this distinction in the App Store review    |
| notes at submission time. The submission flow must NEVER mention or   |
| link to a payment URL from inside the iOS app --- the user is told    |
| payment instructions will arrive by email, and the actual payment     |
| happens entirely outside the app surface.                             |
+-----------------------------------------------------------------------+

**5.8 Moderation & admin tooling**

Every new submission, every edit to an existing listing, and every event
submission goes through manual review before going live. There are no
auto-publish paths.

**Admin web panel (separate web app)**

- Authenticated by Sign in with Apple or email --- only allow-listed
  admin emails (initially: just Roar).

- Inbox-style queue: pending submissions ordered by submission time,
  with badge counts per directory.

- For each item: full submission view with all fields, side-by-side diff
  if it is an edit to an existing listing, \"Approve\" / \"Reject (with
  reason)\" / \"Request changes\" actions.

- Reason codes for rejection (sent to submitter automatically):
  Incomplete information, Suspected fraud, Duplicate listing,
  Inappropriate content, Outside scope (not Switzerland / not
  Turkish-community-relevant), Other (free text).

- Bulk actions: approve multiple at once (used for trusted
  re-submissions, e.g. mosques imported in batch).

- Audit log: every admin action logged with timestamp and admin
  identity. Immutable.

- CSV export of all listings for backup.

- Content editor for Welcome Guide, Consulate Info, Privacy, Terms,
  About --- markdown-based.

- Push notification composer: subject, body, target audience (all
  logged-in users / kanton / saved-search subscribers), preview,
  scheduled or send-now.

**Admin notification channel**

Daily email digest of pending items (sent at 09:00 CET if any items are
pending). Critical items (3+ user reports on a single listing) trigger
an immediate email. No Telegram bot in v1.

**User-side reporting**

- Every listing has a \"Report\" link. Requires login (filters out
  drive-by trolling).

- Reasons: Incorrect info, Closed/no longer exists, Suspected fraud,
  Inappropriate, Other.

- Reports go to the admin email digest, accumulated per listing. Three
  reports on a single listing automatically suspend it pending review.

**5.9 Push notifications**

- Implementation: Apple Push Notification service (APNs) via the
  backend.

- Permission requested at a contextual moment (after first event view),
  not at first launch.

- Categories the user can opt into individually:

  - • New events in my kanton

  - • Editorial updates (consulate news, app announcements written by
    Roar)

  - • Saved-search matches

  - • My listing status (provider only --- submission approved, expiring
    soon, etc.)

- Admin can broadcast editorial pushes from the admin panel with a
  preview and confirmation step.

**5.10 Offline behavior**

- **Always available offline:** Welcome Guide, Emergency Numbers,
  Consulate Info, Privacy/Terms, the user\'s favorited listings.

- **Cached but stale-acceptable:** Last-viewed directory results
  (visible with a \"showing offline data\" banner; refresh button
  revealed).

- **Requires connection:** Search, listing submission, payment flow,
  push registration.

- Strategy: SwiftData / CoreData local store; backend exposes
  ETag/If-None-Match headers for efficient delta sync.

**6. Data Model**

The backend uses PostgreSQL. Multi-tenant features are not needed ---
single-tenant, single-region for data residency proximity to
Switzerland. Below are the core entities and their key relationships.

**6.1 Core entities**

  --------------------------------------------------------------------------
  **Entity**    **Key fields**                     **Relationships**
  ------------- ---------------------------------- -------------------------
  User          id, email, apple_user_id,          has many Favorite,
                display_name, language,            SavedSearch, Listing
                created_at, deleted_at             

  Listing       id, name, kanton\[\]               belongs to User; has many
                (multi-value), directories\[\]     ListingHistory, Report,
                (multi-value: hukuk, tercüme,      Invoice
                etc.), category, sub_category,     
                address, phone, phone_public       
                (bool), email, email_public        
                (bool), website, description,      
                image_url, owner_id (User,         
                nullable for anonymized), status,  
                package, paid_until, created_at,   
                updated_at, approved_by,           
                approved_at                        

  Event         id, title, description, starts_at, standalone; soft-linked
                ends_at, kanton, venue, address,   to User if submitter
                image_url, submitter_email, status logged in
                (pending/active/past), created_at  

  Favorite      user_id, listing_id, created_at    belongs to User and
                                                   Listing

  SavedSearch   user_id, query, filters (json),    belongs to User
                notify_on_new (bool)               

  Report        id, listing_id, reporter_user_id   belongs to Listing
                (required), reason, notes,         
                created_at, resolved_at            

  Invoice       id, listing_id, invoice_number,    belongs to Listing
                amount_chf, package, issued_at,    
                due_at, paid_at, payment_method    
                (twint/bank), pdf_url              

  ContentPage   slug, title, body_markdown,        standalone (Welcome
                updated_at, updated_by             Guide, Privacy, etc.)

  Kanton        code (AG, AI, \...), name_tr,      reference data, 26 rows
                name_de                            

  Category      id, directory_type, name_tr,       reference data,
                parent_id                          hierarchical
  --------------------------------------------------------------------------

**6.2 Multi-directory listings**

A single listing can appear in multiple directories. The Listing entity
has a directories\[\] field --- an array of directory codes. The list
view for directory X shows all listings where \'X\' ∈
listing.directories. The provider pays once per listing regardless of
how many directories it appears in.

**6.3 Listing status state machine**

A listing\'s status follows a deterministic state machine. Transitions
are server-enforced.

  ------------------------------------------------------------------------
  **From**           **To**             **Trigger**
  ------------------ ------------------ ----------------------------------
  (none)             pending            User submits new listing

  pending            active             Admin approves (first month is
                                        free regardless of payment)

  pending            rejected           Admin rejects with reason

  active             suspended          3+ user reports OR admin manual
                                        suspend OR free month expired
                                        without payment

  active             expired            paid_until \< now()

  expired            active             Owner renews + payment received
                                        within 90 days

  expired            archived           90 days post-expiry, no renewal

  active             pending            Owner edits listing --- re-enters
                                        review

  suspended          active             Admin reviews and reinstates /
                                        payment received

  suspended          archived           Admin confirms violation
  ------------------------------------------------------------------------

**6.4 Migration from v1**

v1\'s data lives in a single Google Sheet (ID
1cVUyaR2kpoYNAv1RCUt4XOIvNeIl03st8P9hd4OdAC4). Engineering will write a
one-shot import script that:

- Pulls each tab (etkinlikler, sağlık, hukuk, işletme, finans, tercüme,
  meslek, mezunlar, okullar, camiler_itdv, DestekDers) via the Sheets
  API.

- Maps each row to a Listing or Event row.

- Imports all entries with status = \"active\" and paid_until =
  (launch_date + 1 month). After the free month, owners must claim their
  listing and pay; otherwise the listing is suspended.

- Surfaces validation errors (missing kanton, malformed phone, etc.) for
  manual cleanup before flipping the live switch.

- Preserves the \"\_old\" sheets as a backup but does not import them.

- Listings imported from v1 do not have an owner_id since v1 has no user
  accounts --- owner_id is NULL until a provider claims the listing via
  a verified email match.

+-----------------------------------------------------------------------+
| **📨 v1 listing claim flow**                                          |
|                                                                       |
| Imported v1 listings start with no owner. To claim ownership, the     |
| original provider signs up with the email address associated with     |
| their listing in the v1 sheet. The system auto-matches the email and  |
| offers a \'Claim this listing\' action. After claim and admin         |
| approval, the provider can edit the listing and pays at the end of    |
| the free first month. Listings unclaimed after 60 days are suspended  |
| (still recoverable if claimed within 90 days).                        |
+-----------------------------------------------------------------------+

**7. Technical Architecture**

**7.1 Stack**

  ------------------------------------------------------------------------
  **Layer**     **Technology**           **Rationale**
  ------------- ------------------------ ---------------------------------
  iOS app       Swift 5.9+, SwiftUI, iOS Native experience, App Store
                16+                      mandate, stated scope. iOS 16+
                                         covers \~95% of active iPhones
                                         and enables NavigationStack +
                                         SwiftData.

  Local         SwiftData (or CoreData   Favorites, cached content,
  persistence   fallback)                offline guide.

  Backend API   FastAPI (Python 3.11+)   Matches the stack used on
                                         ALPAGU/ALPAGUT. Auto-generated
                                         OpenAPI spec simplifies iOS
                                         client generation. Strong async
                                         support.

  Database      PostgreSQL 15+           Strong full-text search (with
                                         Turkish dictionary), mature
                                         ecosystem, multi-value array
                                         fields for kanton\[\] and
                                         directories\[\].

  Object        S3-compatible (Hetzner   Logo and event images.
  storage       Storage Box or AWS S3)   

  Hosting       EU-region (Hetzner Cloud Either acceptable; Hetzner is
                / AWS eu-central-1) ---  cheaper for fixed-size workloads,
                to be selected before    AWS provides more managed
                Phase 1                  services. Decision deferred to
                                         engineering team.

  Push          APNs via backend         Standard.

  Admin panel   React + Vite, separate   Browser-based, allows Roar to
                web deployment           moderate from any device.

  PDF invoicing WeasyPrint (Python)      Server-side rendering of HTML
                                         invoice template; already in the
                                         FastAPI stack.

  Auth          Sign in with Apple +     Apple SIWA mandatory;
                email/password           email/password as fallback. No
                (Argon2id)               email verification step.

  Crash         Sentry                   iOS + backend integrated.
  reporting                              

  Marketing     Cloudflare Pages (static Free, fast, gives a real
  site /        site, custom domain)     CDN-backed home for Privacy,
  privacy                                Terms, marketing pages, and the
                                         v1 deprecation banner content.
  ------------------------------------------------------------------------

**7.2 Security**

- **No client-embedded secrets.** v1 has its Google API key in plain
  client JavaScript. v2 enforces zero secrets in the iOS bundle ---
  every external service is called server-side.

- **TLS everywhere.** HSTS, TLS 1.3, certificate pinning for the API in
  the iOS app.

- **Rate limiting.** Per-IP and per-user rate limits on submission and
  search endpoints.

- Argon2id password hashing for email/password accounts.

- Server-side image validation: file type, dimensions, EXIF stripping
  (privacy + reduces stored bytes).

**7.3 Privacy & data minimization**

- **No anonymous-user telemetry.** Anonymous browsing produces no
  tracking events. Server logs retain IP for 7 days for security/abuse
  purposes only, then rotate.

- **Logged-in user telemetry.** Authenticated users generate session
  events for retention and feature usage analysis. This is disclosed in
  Privacy Policy and is the basis for §2.3 success metrics.

- **Data residency in EU.** All databases and object storage in EU
  regions (Frankfurt or equivalent). FADP / nFADP compliance.

- **Self-serve account deletion.** Profile → Hesabımı Sil. Listings
  handled per §5.6 anonymization rule.

- **No third-party analytics.** Explicitly: no Google Analytics, no
  Facebook Pixel, no Plausible on anonymous traffic, no PostHog on
  anonymous traffic.

- **App Store privacy declarations.** Updated to reflect actual data
  collection --- v1\'s declarations are inaccurate.

**7.4 Performance budgets**

- App cold start to first interactive: \< 1.5 seconds on iPhone 13.

- Directory list load: \< 800ms P95 (warm cache).

- Search query: \< 300ms P95 server-side.

- App size: \< 30 MB (vs. v1\'s 21.5 MB). Budget for SF Symbols, custom
  fonts if needed.

**8. UX & Design Principles**

Detailed design is out of scope for this PRD and will be produced as a
separate design brief. The principles below constrain the visual system
that the design team will produce.

**8.1 Design principles**

- **iOS-native first.** The app should feel like an iOS app, not a web
  app or a cross-platform app. Use SF Pro, system colors, native
  sheet/navigation idioms.

- **Calm, not loud.** This is a reference utility, not a social app.
  Restrained color palette, generous whitespace, no gamification UI
  clutter.

- **Density where useful.** In list views, prioritize information
  density over decoration. Users are scanning for a name and a kanton,
  not enjoying card animations.

- **One-tap to action.** From the moment the user opens a listing,
  calling/emailing/navigating must be one tap each. No nested menus.

- **No badges, no rankings, no opinions.** The directory presents
  listings without visual judgment --- no \'Verified\', \'Sponsored\',
  \'Featured\', or rating indicators. The user decides who to call.

**8.2 Accessibility**

- Dynamic Type support throughout (no hardcoded font sizes that break at
  large accessibility text settings).

- VoiceOver labels on all interactive elements.

- Minimum tap target 44×44 pt.

- Color contrast meets WCAG AA (4.5:1 body text, 3:1 large text).

- Light and Dark mode both supported from day one.

**9. Compliance, Legal & App Store**

**9.1 Apple App Store guidelines**

  --------------------------------------------------------------------------
  **Guideline**     **Risk area**         **Mitigation**
  ----------------- --------------------- ----------------------------------
  3.1.1 (IAP)       Selling listings      Listings are advertising/services,
                    without IAP           not in-app digital content.
                                          Document in review notes; never
                                          link to external payment from
                                          inside the app.

  4.0 (Design)      WebView-heavy v1 was  v2 is fully native --- no risk.
                    borderline            

  5.1.1(v) (Account Required for any app  Self-serve deletion in Profile →
  deletion)         with accounts         Settings.

  5.1.2 (Data       Privacy declarations  Privacy nutrition label rewritten
  sharing)          must match reality    from scratch based on actual data
                                          flows. Anonymous users: no data
                                          collected.

  1.2               Listings & events are Manual moderation, login-required
  (User-Generated   UGC                   reporting, admin suspend
  Content)                                mechanism.

  1.6 (Safety /     Lawyer/health         Manual review; clear disclaimer
  fraud)            listings could enable that ITT does not vouch for
                    fraud                 individual professionals\'
                                          qualifications (in Terms and on
                                          relevant directory list views).
  --------------------------------------------------------------------------

**9.2 Swiss legal**

- **Swiss Federal Act on Data Protection (FADP / nFADP, in force Sept
  2023).** Privacy notice must list controller identity, purposes,
  recipients, retention. We comply by treating FADP as functionally
  equivalent to GDPR for our scope.

- **Imprint requirement.** Operating entity is Roar (Yusuf Berkan Altun)
  personally --- full legal name and contact in About page. If a Swiss
  legal person is later created to hold the app, the imprint updates
  accordingly.

- **VAT (MwSt).** If listing revenue exceeds 100,000 CHF/year, Swiss VAT
  registration is mandatory. PDF invoices include MwSt where applicable;
  flag at 50,000 CHF/year for tax-advisor consultation.

- **Professional listings disclaimer.** App must clearly state:
  ITT-Rehber does not verify professional credentials of listed
  providers; users are responsible for verifying qualifications
  independently.

- **Refund policy disclosure.** ToS clearly states \'No refunds ---
  listings are non-refundable services.\' Stated again at checkout, with
  provider explicitly accepting before payment.

**9.3 GDPR (for users physically in EU)**

- Lawful basis for processing: consent (account creation), contract
  (paid listings). No legitimate-interest tracking of anonymous users.

- DPA with Apple (APNs), the chosen hosting provider, and Cloudflare
  Pages.

- Data subject rights: access, rectification, deletion, portability ---
  all implementable via the existing Profile interface.

**10. Roadmap & Phasing**

The build is organized into four phases. Phase milestones are gates: a
phase is not complete until all its acceptance criteria are met.
Timelines are deliberately not specified --- they depend on team size
and budget, both of which are downstream of this PRD.

**Phase 1 --- Foundation**

- Backend skeleton: Postgres, FastAPI, auth (Sign in with Apple +
  email/password), S3 storage.

- iOS app skeleton: SwiftUI, navigation, sample directory list view.

- Admin panel skeleton: login, queue UI, approve/reject for one
  directory type.

- CI/CD: TestFlight pipeline, backend deploy pipeline.

- Hosting decision finalized (Hetzner vs AWS).

- Acceptance: end-to-end submit → moderate → display flow works for one
  directory (Sağlık).

**Phase 2 --- Directories & content**

- All 10 directories + Events implemented.

- Search across all directories with PostgreSQL full-text + Turkish
  stemming.

- Welcome Guide and other static content pages.

- User accounts (Sign in with Apple + email/password, no email
  verification).

- Favorites and Saved Searches.

- Migration script imports v1 data; QA validates against source sheet.

- v1 listing claim flow.

- Acceptance: all v1 functionality is present and improved (search, real
  date filtering on events, mandatory listing images).

**Phase 3 --- Monetization**

- Paid listing submission flow with multi-directory and multi-kanton
  support.

- PDF invoice generation, TWINT QR generation, email delivery.

- Admin payment reconciliation interface.

- Renewal flow and expiry handling.

- Push notifications (APNs).

- Acceptance: end-to-end provider can submit, receive invoice, pay, and
  see listing live within 24 hours of admin approval.

**Phase 4 --- Launch**

- Closed beta via TestFlight (50 users).

- App Store submission, review, and approval. Submission review notes
  explicitly cover the 3.1.3(b) listing-fee exemption.

- Open beta.

- Public launch as a fresh app under Roar\'s personal Apple Developer
  account.

- v1 deprecation banner added to v1 (via the existing Apps Script entry
  point) pointing to the new app.

- Acceptance: app live in App Store, performance budgets met, crash-free
  rate ≥ 99.5% in first week.

**11. Risks & Open Questions**

**11.1 Risks**

  ---------------------------------------------------------------------------------
  **Risk**               **Likelihood**   **Impact**   **Mitigation**
  ---------------------- ---------------- ------------ ----------------------------
  Apple rejects app for  Low              High         Document the 3.1.3(b)
  non-IAP payment                                      exemption in review notes;
                                                       never link to external
                                                       payment from inside the app;
                                                       payment flow happens
                                                       entirely via email.

  Manual moderation does Medium           Medium       Build admin panel with bulk
  not scale                                            actions and reason-code
                                                       shortcuts; recruit a
                                                       part-time community
                                                       moderator if submissions
                                                       exceed 50/week.

  v1 users do not find   Medium           Medium       Soft launch is the chosen
  v2                                                   strategy. v1 deprecation
                                                       banner is the primary
                                                       discovery mechanism.
                                                       Acceptable trade-off for
                                                       launch simplicity; can add
                                                       migration emails later if
                                                       discovery is too slow.

  Low willingness to pay Medium           High         First month free as
  among providers                                      acquisition tool;
                                                       multi-directory single-fee
                                                       is generous. If \< 20% paid
                                                       retention after free month,
                                                       revisit pricing or add a
                                                       \"donation\" tier.

  v1 listings unclaimed  High             Medium       60-day grace period for
  after import                                         claims; then suspended
                                                       (recoverable for another 30
                                                       days). Roar can also
                                                       bulk-message via email
                                                       contacts in v1 data.

  TWINT/bank             Medium           Low          Manual review of \"paid\"
  reconciliation errors                                status by admin before
                                                       unlocking listing
                                                       post-free-month.

  Image moderation       Low              Medium       Manual review covers this;
  (logos, photos)                                      defer automated image
                                                       moderation to v2.x.

  Acquisition deal with  Low              High         Acquisition must close
  Fatih falls through                                  before Phase 1 begins. v2
                                                       cannot use v1 data,
                                                       branding, or App Store
                                                       metadata without IP
                                                       transfer.
  ---------------------------------------------------------------------------------

**11.2 Open questions for engineering team**

- **Q1:** Hosting provider final decision --- Hetzner Cloud (cheaper,
  EU-based) vs AWS eu-central-1 (more managed services, higher cost).
  Decision needed before Phase 1 kickoff.

- **Q2:** Image processing pipeline --- server-side resize/optimize on
  upload, or rely on Cloudflare Image Resizing? Affects cost model.

- **Q3:** Push notification batching --- when Roar sends an editorial
  push to all kanton-X users, is it one batch APNs request or
  individual? Affects rate limits and observability.

- **Q4:** Backup and disaster recovery --- Postgres backup cadence
  (daily? hourly?), retention period, restore drill schedule.

- **Q5:** Multi-environment strategy --- staging environment
  requirements, data parity, secrets isolation.

**11.3 Open questions for business/legal**

- **Q1:** Acquisition close timeline --- when does the deal with Fatih
  sign? Must close before Phase 1 kickoff so the team has IP clarity.

- **Q2:** VAT registration --- Roar should consult a Swiss tax advisor
  about timing of MwSt registration. The app should support
  MwSt-on-invoice from day one even if not yet active.

- **Q3:** Photography rights for provider-uploaded images --- providers
  must warrant they have rights to images they upload; should be a
  checkbox in the submission flow with explicit ToS language.

- **Q4:** Custom domain for the marketing site --- what domain name does
  Roar own/want for the Cloudflare Pages site? (Privacy + Terms +
  landing page.)

**12. Decision Log**

Decisions locked during PRD scoping. This section is the authoritative
answer when implementation questions arise.

  -----------------------------------------------------------------------
  **Decision area**        **Locked decision**
  ------------------------ ----------------------------------------------
  Platform                 Native iOS only (no Android, no
                           cross-platform)

  Minimum iOS version      iOS 16+

  Backend stack            FastAPI (Python) + PostgreSQL

  Hosting region           EU (specific provider TBD before Phase 1)

  UI language              Turkish only at launch (App Store metadata
                           corrected)

  Account model            Optional accounts; anonymous browsing default

  Email verification       None --- admin moderation handles fakes

  Pricing                  60 / 100 / 180 CHF for 3 / 6 / 12 months

  First month              Free for all listings (new and v1 migrants)

  Multi-directory listings Single listing covers multiple directories at
                           no extra cost

  Multi-kanton listings    Single listing covers multiple kantons at no
                           extra cost

  Multi-location           Pay separately per location
  businesses               

  Payment methods          TWINT and bank transfer (no IAP, no in-app
                           payment)

  Invoice format           PDF, generated server-side, sent by email

  Refund policy            No refunds --- listings non-refundable

  Moderation               Manual review before publish; admin email
                           digest

  Reviews & ratings        Excluded from product (not deferred, removed)

  Trust badges             No \"Verified\" or \"Sponsored\" indicators

  Listing tiers            Single flat-fee tier (no Premium/Featured)

  Listing image            Mandatory upload

  Contact field visibility Provider chooses per-field for email and phone

  User-side reporting      Login required

  Anonymous-user analytics Not collected

  Editorial content        Roar personally
  authorship               

  Events search bar        No (filter-only browsing)

  Event submission         Open to anyone, no account required, moderated

  User → listing           One user can own multiple listings
  relationship             

  Account deletion +       Listings stay active until expiry, ownership
  active listings          anonymized

  v1 sunset strategy       Soft launch + v1 \'deprecated\' banner

  v1 user migration UX     No migration email/push --- organic discovery

  Admin notification       Daily email digest (no Telegram)
  channel                  

  v1 → v2 listing claim    Email-match-based self-service claim

  Marketing site           Cloudflare Pages, free tier

  Legal entity             Roar (Yusuf Berkan Altun) personally for v1;
                           Swiss entity TBD later

  v1 acquisition           Outright IP buyout from Fatih Karaoglu

  App Store account        Fresh Roar-personal account (not transferring
                           v1 listing)
  -----------------------------------------------------------------------

**13. Glossary**

  -----------------------------------------------------------------------
  **Term**           **Meaning**
  ------------------ ----------------------------------------------------
  Kanton             Swiss canton --- the 26 federal subdivisions of
                     Switzerland (AG, AI, AR, BE, BL, BS, FR, GE, GL, GR,
                     JU, LU, NE, NW, OW, SG, SH, SO, SZ, TG, TI, UR, VD,
                     VS, ZG, ZH)

  Directory          One of ten themed lists of providers (Health, Legal,
                     Business, etc.)

  Listing            A single entry within one or more directories ---
                     one provider

  Lehre /            Swiss apprenticeship system; Schnupperlehre is the
  Schnupperlehre     trial week

  Diyanet            Turkish Directorate of Religious Affairs; mosques
                     affiliated with this body

  IAP                In-App Purchase --- Apple\'s payment system, NOT
                     used in this product

  TWINT              Swiss mobile payment system (the local equivalent of
                     Venmo / Wise)

  MwSt               Mehrwertsteuer --- Swiss VAT

  FADP / nFADP       Swiss Federal Act on Data Protection (revised 2023)

  APNs               Apple Push Notification service

  SIWA               Sign in with Apple

  CMS                Content Management System --- here, the admin panel
                     for editorial content

  SF Pro             Apple\'s system font for iOS

  Argon2id           Modern password hashing algorithm (winner of the
                     Password Hashing Competition)
  -----------------------------------------------------------------------

*--- End of document ---*
