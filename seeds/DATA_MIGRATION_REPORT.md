# ITT Rehber v1 → v2 Data Migration Report

**Source:** 2 Google Sheets (SS1 = production, SS2 = partially filled v2 draft)
**Total clean listings:** 174
**Events:** 4
**Schools:** 141 Turkish language school branches
**Mosques/Associations:** 47 ITDV-linked associations

## Listings by directory

| Directory | Count | Email fill | Phone fill | Image fill |
|-----------|-------|-----------|-----------|-----------|
| destek_dersi | 2 | 100% | 100% | 50% |
| finans | 36 | 17% | 14% | 17% |
| hukuk | 12 | 42% | 42% | 42% |
| isletme | 37 | 76% | 95% | 100% |
| meslek | 1 | 0% | 0% | 0% |
| mezunlar | 4 | 0% | 0% | 0% |
| saglik | 52 | 35% | 44% | 42% |
| tercume | 30 | 7% | 7% | 7% |

## What was cleaned

- **Dummy rows removed:** rows with `name@mail.com`, `me@mail.com`, test phone numbers (`079 456 78 90` etc.), test addresses (`Bundesplatz 1`)
- **ITT placeholder rows removed:** listings named `.İsviçre Türk Toplumu İTT` or `İTT` used as admin placeholders
- **Alumni (`mezunlar`) dummies removed:** 28 `zz_Ad Soyad` placeholder rows dropped; 4 real entries kept
- **Deduplication:** SS1 + SS2 merged; where same name+kanton+directory existed, kept the record with more non-null fields
- **Kanton normalisation:** full German/Turkish names → 2-letter codes (`Zürih` → `ZH`, `Bern` → `BE`, etc.)
- **Phone normalisation:** whitespace cleaned; phone numbers matching test patterns set to NULL
- **`Avantaj` column dropped:** 91% empty — not seeded

## Gaps to fill before launch

- **`meslek`:** 1 real entry — feature sparse, defer bulk outreach to Phase 2
- **`destek_dersi`:** 2 real entries — needs outreach campaign
- **`tercüme`:** 30 entries but 93% have no contact info — names collected but contacts missing
- **`mezunlar`:** 4 real entries + 28 empties purged — alumni feature needs re-launch with submission form
- **`finans` contact quality:** many entries have name + category but no phone/email (collected from ITDV website)
- **Images:** 77 images still hosted on Google Photos / old WordPress — run `seeds/download_images.py` then upload to R2
- **Events:** only 4 upcoming events seeded (2 festivals, 2 days each) — plug into submission flow

## File manifest

```
seeds/
  seed_v1_migration.sql   ← run AFTER 0003 migration
  0003_schools_mosques.sql ← new tables DDL
  saglik.json             ← 52 listings
  hukuk.json              ← 12 listings
  isletme.json            ← 37 listings
  finans.json             ← 36 listings
  tercume.json            ← 30 listings
  meslek.json             ←  1 listing
  mezunlar.json           ←  4 listings
  destek_dersi.json       ←  2 listings
  events.json             ←  4 events
  schools.json            ← 141 school branches
  mosques.json            ←  47 ITDV associations
  download_images.py      ← downloads 77 images to seeds/images/
```