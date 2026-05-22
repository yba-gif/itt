"""Search helpers.

Phase 2 Postgres FTS: ``tsvector`` column on ``listings.search_tsv`` populated
by trigger from ``name || category || sub_category || description || array_to_string(kantons,' ')``.
We use the ``simple`` configuration with ``unaccent`` for now — Turkish-aware
stemming (using PostgreSQL's snowball ``turkish`` config or a custom hunspell
dictionary) is research work tracked in docs/architecture.md and deferred.

The ``simple`` config with unaccent already handles the most common case:
"Sağlık" matches "saglik", "İşletme" matches "isletme", and the user can
type accented or unaccented and find the same provider.
"""

from __future__ import annotations

from sqlalchemy import Select, func, or_, text


def apply_fts(stmt: Select, q: str) -> Select:
    """Filter a Listing select by a free-text query, ranking by relevance.

    Falls back to ILIKE if the FTS column hasn't been populated (covers the
    transient state immediately after migration before the trigger fires
    on insert/update of existing rows — see Alembic 0002).
    """
    from app.models.listing import Listing

    cleaned = q.strip()
    if not cleaned:
        return stmt

    # tsquery: split user input on whitespace and AND the lexemes, prefix-matched.
    # plainto_tsquery('simple', unaccent(:q)) is too strict (no prefix); we
    # build the query manually so the user gets prefix-match for free.
    tokens = [t for t in cleaned.split() if t]
    tsquery_text = " & ".join(f"{t}:*" for t in tokens) if tokens else cleaned

    fts_pred = Listing.search_tsv.op("@@")(
        func.to_tsquery("simple", func.unaccent(tsquery_text))
    )
    ilike_pred = or_(
        Listing.name.ilike(f"%{cleaned}%"),
        Listing.category.ilike(f"%{cleaned}%"),
        Listing.sub_category.ilike(f"%{cleaned}%"),
        Listing.address.ilike(f"%{cleaned}%"),
        Listing.description.ilike(f"%{cleaned}%"),
        # `directories` is an ARRAY(String) — use any_ for membership test
        Listing.directories.any(cleaned.lower()),
    )
    return stmt.where(or_(fts_pred, ilike_pred))


# A literal version for raw SQL contexts (e.g., the migration trigger DDL).
# Must stay in sync with the trigger function defined in Alembic 0005.
LISTING_TSV_EXPR = text(
    "to_tsvector('simple', unaccent("
    "coalesce(NEW.name,'') || ' ' || "
    "coalesce(NEW.category,'') || ' ' || "
    "coalesce(NEW.sub_category,'') || ' ' || "
    "coalesce(NEW.description,'') || ' ' || "
    "coalesce(NEW.address,'') || ' ' || "
    "coalesce(array_to_string(NEW.kantons, ' '), '') || ' ' || "
    "coalesce(array_to_string(NEW.directories, ' '), '')"
    "))"
)
