"""Phase 2 FTS: tsvector column + trigger + GIN index on listings.

Revision ID: 0002_fts
Revises: 0001_initial
Create Date: 2026-05-04

"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0002_fts"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Build the tsvector from name + category + sub_category + description + kantons.
# We use the `simple` config + unaccent so accented Turkish input matches
# unaccented stored data (common case: user types "saglik" -> matches "Sağlık").
TSV_EXPR = (
    "to_tsvector('simple', unaccent("
    "coalesce(NEW.name,'') || ' ' || "
    "coalesce(NEW.category,'') || ' ' || "
    "coalesce(NEW.sub_category,'') || ' ' || "
    "coalesce(NEW.description,'') || ' ' || "
    "coalesce(array_to_string(NEW.kantons, ' '), '')"
    "))"
)

BACKFILL_TSV_EXPR = (
    "to_tsvector('simple', unaccent("
    "coalesce(name,'') || ' ' || "
    "coalesce(category,'') || ' ' || "
    "coalesce(sub_category,'') || ' ' || "
    "coalesce(description,'') || ' ' || "
    "coalesce(array_to_string(kantons, ' '), '')"
    "))"
)


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS unaccent")

    op.execute("ALTER TABLE listings ADD COLUMN IF NOT EXISTS search_tsv tsvector")

    op.execute(f"""
        CREATE OR REPLACE FUNCTION listings_search_tsv_trigger() RETURNS trigger AS $$
        BEGIN
            NEW.search_tsv := {TSV_EXPR};
            RETURN NEW;
        END
        $$ LANGUAGE plpgsql
    """)

    op.execute("DROP TRIGGER IF EXISTS listings_search_tsv_update ON listings")
    op.execute("""
        CREATE TRIGGER listings_search_tsv_update
        BEFORE INSERT OR UPDATE OF name, category, sub_category, description, kantons
        ON listings
        FOR EACH ROW EXECUTE FUNCTION listings_search_tsv_trigger()
    """)

    # Backfill any existing rows.
    op.execute(f"UPDATE listings SET search_tsv = {BACKFILL_TSV_EXPR}")

    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_listings_search_tsv
        ON listings USING GIN (search_tsv)
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_listings_search_tsv")
    op.execute("DROP TRIGGER IF EXISTS listings_search_tsv_update ON listings")
    op.execute("DROP FUNCTION IF EXISTS listings_search_tsv_trigger()")
    op.execute("ALTER TABLE listings DROP COLUMN IF EXISTS search_tsv")
