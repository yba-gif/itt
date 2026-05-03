"""26 Swiss cantons (PRD §13 glossary)."""

from __future__ import annotations

KANTONS: list[tuple[str, str, str]] = [
    # (code, name_tr, name_de)
    ("AG", "Aargau", "Aargau"),
    ("AI", "Appenzell İçi", "Appenzell Innerrhoden"),
    ("AR", "Appenzell Dışı", "Appenzell Ausserrhoden"),
    ("BE", "Bern", "Bern"),
    ("BL", "Basel-Land", "Basel-Landschaft"),
    ("BS", "Basel-Şehir", "Basel-Stadt"),
    ("FR", "Fribourg", "Freiburg"),
    ("GE", "Cenevre", "Genf"),
    ("GL", "Glarus", "Glarus"),
    ("GR", "Graubünden", "Graubünden"),
    ("JU", "Jura", "Jura"),
    ("LU", "Luzern", "Luzern"),
    ("NE", "Neuchâtel", "Neuenburg"),
    ("NW", "Nidwalden", "Nidwalden"),
    ("OW", "Obwalden", "Obwalden"),
    ("SG", "St. Gallen", "St. Gallen"),
    ("SH", "Schaffhausen", "Schaffhausen"),
    ("SO", "Solothurn", "Solothurn"),
    ("SZ", "Schwyz", "Schwyz"),
    ("TG", "Thurgau", "Thurgau"),
    ("TI", "Ticino", "Tessin"),
    ("UR", "Uri", "Uri"),
    ("VD", "Vaud", "Waadt"),
    ("VS", "Valais", "Wallis"),
    ("ZG", "Zug", "Zug"),
    ("ZH", "Zürih", "Zürich"),
]
