"""Seed categories per directory (Phase 1 minimum — Sağlık fully populated, others sparse)."""

from __future__ import annotations

# (directory_code, [category_name_tr, ...])
CATEGORIES: dict[str, list[str]] = {
    "saglik": [
        "Aile Hekimi",
        "Diş Hekimi",
        "Pediatri",
        "Kadın Doğum",
        "Psikolog / Psikiyatr",
        "Fizyoterapi",
        "Göz Hekimi",
        "Dermatoloji",
        "Diğer Uzmanlık",
    ],
    "hukuk": [
        "Avukat",
        "Noter",
        "Göçmenlik Danışmanı",
    ],
    "isletme": [
        "Restoran",
        "Market",
        "Perakende",
        "Hizmet",
    ],
    "finans": [
        "Sigorta Brokeri",
        "Vergi Danışmanı",
        "Muhasebeci",
    ],
    "tercume": [
        "Yeminli Tercüman",
        "İnformel Tercüman",
    ],
    "meslek": [
        "Lehre / Çıraklık",
        "Schnupperlehre",
    ],
    "okullar": [
        "Türkçe Cumartesi Okulu",
        "Türkçe Pazar Okulu",
    ],
    "camiler": [
        "Diyanet Camii",
    ],
    "mezunlar": [
        "ETH Zürich",
        "EPFL",
        "Universität Zürich",
        "Universität Basel",
        "Universität Bern",
        "Diğer",
    ],
    "destek_dersi": [
        "Matematik",
        "Almanca",
        "Fransızca",
        "İngilizce",
        "Diğer",
    ],
}
