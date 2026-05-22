"""Phase 2: include `directories` and `address` in the search tsvector.

Bug: searching for "hukuk" returned 0 hits despite 12 hukuk-directory listings
existing. The tsvector built by migration 0002 only covered
name + category + sub_category + description + kantons, so directory codes
("saglik", "hukuk", "okullar", ...) were not searchable.

Fix: rebuild the trigger function to also concatenate
`array_to_string(directories, ' ')` and `address`, then backfill existing rows.

Revision ID: 0005_search_directories
Revises: 0004_widen_category
Create Date: 2026-05-22
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0005_search_directories"
down_revision: Union[str, None] = "0004_widen_category"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# New tsvector expression — adds directories + address to the existing fields.
NEW_TSV_EXPR = (
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

NEW_BACKFILL_EXPR = (
    "to_tsvector('simple', unaccent("
    "coalesce(name,'') || ' ' || "
    "coalesce(category,'') || ' ' || "
    "coalesce(sub_category,'') || ' ' || "
    "coalesce(description,'') || ' ' || "
    "coalesce(address,'') || ' ' || "
    "coalesce(array_to_string(kantons, ' '), '') || ' ' || "
    "coalesce(array_to_string(directories, ' '), '')"
    "))"
)

# Old (pre-0005) expression used by the downgrade path.
OLD_TSV_EXPR = (
    "to_tsvector('simple', unaccent("
    "coalesce(NEW.name,'') || ' ' || "
    "coalesce(NEW.category,'') || ' ' || "
    "coalesce(NEW.sub_category,'') || ' ' || "
    "coalesce(NEW.description,'') || ' ' || "
    "coalesce(array_to_string(NEW.kantons, ' '), '')"
    "))"
)

OLD_BACKFILL_EXPR = (
    "to_tsvector('simple', unaccent("
    "coalesce(name,'') || ' ' || "
    "coalesce(category,'') || ' ' || "
    "coalesce(sub_category,'') || ' ' || "
    "coalesce(description,'') || ' ' || "
    "coalesce(array_to_string(kantons, ' '), '')"
    "))"
)


def upgrade() -> None:
    # Replace trigger function with directories + address included
    op.execute(f"""
        CREATE OR REPLACE FUNCTION listings_search_tsv_trigger() RETURNS trigger AS $$
        BEGIN
            NEW.search_tsv := {NEW_TSV_EXPR};
            RETURN NEW;
        END
        $$ LANGUAGE plpgsql
    """)

    # Recreate trigger so it also fires on directories/address changes
    op.execute("DROP TRIGGER IF EXISTS listings_search_tsv_update ON listings")
    op.execute("""
        CREATE TRIGGER listings_search_tsv_update
        BEFORE INSERT OR UPDATE OF name, category, sub_category, description,
                                   address, kantons, directories
        ON listings
        FOR EACH ROW EXECUTE FUNCTION listings_search_tsv_trigger()
    """)

    # Backfill all existing rows with the new tsvector
    op.execute(f"UPDATE listings SET search_tsv = {NEW_BACKFILL_EXPR}")


def downgrade() -> None:
    op.execute(f"""
        CREATE OR REPLACE FUNCTION listings_search_tsv_trigger() RETURNS trigger AS $$
        BEGIN
            NEW.search_tsv := {OLD_TSV_EXPR};
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

    op.execute(f"UPDATE listings SET search_tsv = {OLD_BACKFILL_EXPR}")
