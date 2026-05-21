"""Widen listings.category and sub_category from varchar(64) to varchar(255).

Revision ID: 0004_widen_category
Revises: 0003_device_tokens
Create Date: 2026-05-21

Rationale: v1 migration data contains multi-service category strings such as
"Market, Danışmanlık, Nakliye, Restoran, Kafe, Butik, Kasap, Fırın" (65 chars)
that exceed the original 64-char limit. The FTS trigger references these columns
so it must be dropped and recreated around the ALTER.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0004_widen_category"
down_revision: Union[str, None] = "0003_device_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # The FTS trigger fires on UPDATE OF category, so Postgres blocks a
    # direct ALTER. Drop, widen, recreate.
    op.execute("DROP TRIGGER IF EXISTS listings_search_tsv_update ON listings")
    op.execute("ALTER TABLE listings ALTER COLUMN category TYPE varchar(255)")
    op.execute("ALTER TABLE listings ALTER COLUMN sub_category TYPE varchar(255)")
    op.execute("""
        CREATE TRIGGER listings_search_tsv_update
        BEFORE INSERT OR UPDATE OF name, category, sub_category, description, kantons
        ON listings
        FOR EACH ROW EXECUTE FUNCTION listings_search_tsv_trigger()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS listings_search_tsv_update ON listings")
    op.execute("ALTER TABLE listings ALTER COLUMN category TYPE varchar(64)")
    op.execute("ALTER TABLE listings ALTER COLUMN sub_category TYPE varchar(64)")
    op.execute("""
        CREATE TRIGGER listings_search_tsv_update
        BEFORE INSERT OR UPDATE OF name, category, sub_category, description, kantons
        ON listings
        FOR EACH ROW EXECUTE FUNCTION listings_search_tsv_trigger()
    """)
