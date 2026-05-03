"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-04

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


LISTING_STATUS = ("pending", "active", "rejected", "suspended", "expired", "archived")
LISTING_PACKAGE = ("months_3", "months_6", "months_12")
EVENT_STATUS = ("pending", "active", "rejected")
PAYMENT_METHOD = ("twint", "bank")


def upgrade() -> None:
    # extensions are loaded by alembic/init.sql at Postgres init; safe-guard here.
    op.execute("CREATE EXTENSION IF NOT EXISTS unaccent")
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # create_type=False so subsequent op.create_table doesn't try to re-CREATE TYPE.
    listing_status = postgresql.ENUM(*LISTING_STATUS, name="listing_status", create_type=False)
    listing_package = postgresql.ENUM(*LISTING_PACKAGE, name="listing_package", create_type=False)
    event_status = postgresql.ENUM(*EVENT_STATUS, name="event_status", create_type=False)
    payment_method = postgresql.ENUM(*PAYMENT_METHOD, name="payment_method", create_type=False)
    # Explicit creation, idempotent.
    postgresql.ENUM(*LISTING_STATUS, name="listing_status").create(op.get_bind(), checkfirst=True)
    postgresql.ENUM(*LISTING_PACKAGE, name="listing_package").create(op.get_bind(), checkfirst=True)
    postgresql.ENUM(*EVENT_STATUS, name="event_status").create(op.get_bind(), checkfirst=True)
    postgresql.ENUM(*PAYMENT_METHOD, name="payment_method").create(op.get_bind(), checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False, unique=True),
        sa.Column("apple_user_id", sa.String(256), unique=True),
        sa.Column("password_hash", sa.String(256)),
        sa.Column("display_name", sa.String(120)),
        sa.Column("language", sa.String(8), nullable=False, server_default="tr"),
        sa.Column("is_admin", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_apple_user_id", "users", ["apple_user_id"], unique=True)

    op.create_table(
        "kantons",
        sa.Column("code", sa.String(2), primary_key=True),
        sa.Column("name_tr", sa.String(64), nullable=False),
        sa.Column("name_de", sa.String(64), nullable=False),
    )

    op.create_table(
        "categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("directory", sa.String(32), nullable=False),
        sa.Column("name_tr", sa.String(120), nullable=False),
        sa.Column("parent_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("categories.id", ondelete="SET NULL")),
    )
    op.create_index("ix_categories_directory", "categories", ["directory"])

    op.create_table(
        "listings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("contact_person", sa.String(120)),
        sa.Column("directories", postgresql.ARRAY(sa.String(32)), nullable=False, server_default="{}"),
        sa.Column("kantons", postgresql.ARRAY(sa.String(2)), nullable=False, server_default="{}"),
        sa.Column("category", sa.String(64)),
        sa.Column("sub_category", sa.String(64)),
        sa.Column("address", sa.String(256)),
        sa.Column("phone", sa.String(64)),
        sa.Column("phone_public", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("email", sa.String(320)),
        sa.Column("email_public", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("website", sa.String(512)),
        sa.Column("description", sa.Text),
        sa.Column("image_url", sa.String(1024)),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("status", listing_status, nullable=False, server_default="pending"),
        sa.Column("package", listing_package),
        sa.Column("paid_until", sa.DateTime(timezone=True)),
        sa.Column("rejection_reason", sa.String(64)),
        sa.Column("rejection_notes", sa.Text),
        sa.Column("approved_by", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("approved_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_listings_owner_id", "listings", ["owner_id"])
    op.create_index("ix_listings_status", "listings", ["status"])
    op.create_index("ix_listings_directories_gin", "listings", ["directories"], postgresql_using="gin")
    op.create_index("ix_listings_kantons_gin", "listings", ["kantons"], postgresql_using="gin")

    op.create_table(
        "events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True)),
        sa.Column("kanton", sa.String(2), nullable=False),
        sa.Column("venue", sa.String(200)),
        sa.Column("address", sa.String(256)),
        sa.Column("image_url", sa.String(1024)),
        sa.Column("submitter_email", sa.String(320)),
        sa.Column("submitter_user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("status", event_status, nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_events_starts_at", "events", ["starts_at"])
    op.create_index("ix_events_kanton", "events", ["kanton"])
    op.create_index("ix_events_status", "events", ["status"])

    op.create_table(
        "favorites",
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("user_id", "listing_id"),
    )

    op.create_table(
        "saved_searches",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("query", sa.String(200)),
        sa.Column("filters", postgresql.JSONB, nullable=False, server_default="{}"),
        sa.Column("notify_on_new", sa.Boolean, nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_saved_searches_user_id", "saved_searches", ["user_id"])

    op.create_table(
        "reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reporter_user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reason", sa.String(64), nullable=False),
        sa.Column("notes", sa.Text),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("resolved_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_reports_listing_id", "reports", ["listing_id"])

    op.create_table(
        "invoices",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("listing_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("listings.id", ondelete="CASCADE"), nullable=False),
        sa.Column("invoice_number", sa.String(32), nullable=False, unique=True),
        sa.Column("amount_chf", sa.Integer, nullable=False),
        sa.Column("package", sa.String(32), nullable=False),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("due_at", sa.DateTime(timezone=True)),
        sa.Column("paid_at", sa.DateTime(timezone=True)),
        sa.Column("payment_method", payment_method),
        sa.Column("pdf_url", sa.String(1024)),
    )
    op.create_index("ix_invoices_listing_id", "invoices", ["listing_id"])

    op.create_table(
        "content_pages",
        sa.Column("slug", sa.String(64), primary_key=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body_markdown", sa.Text, nullable=False, server_default=""),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_by", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="SET NULL")),
    )


def downgrade() -> None:
    op.drop_table("content_pages")
    op.drop_index("ix_invoices_listing_id", table_name="invoices")
    op.drop_table("invoices")
    op.drop_index("ix_reports_listing_id", table_name="reports")
    op.drop_table("reports")
    op.drop_index("ix_saved_searches_user_id", table_name="saved_searches")
    op.drop_table("saved_searches")
    op.drop_table("favorites")
    op.drop_index("ix_events_status", table_name="events")
    op.drop_index("ix_events_kanton", table_name="events")
    op.drop_index("ix_events_starts_at", table_name="events")
    op.drop_table("events")
    op.drop_index("ix_listings_kantons_gin", table_name="listings")
    op.drop_index("ix_listings_directories_gin", table_name="listings")
    op.drop_index("ix_listings_status", table_name="listings")
    op.drop_index("ix_listings_owner_id", table_name="listings")
    op.drop_table("listings")
    op.drop_index("ix_categories_directory", table_name="categories")
    op.drop_table("categories")
    op.drop_table("kantons")
    op.drop_index("ix_users_apple_user_id", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
    for enum_name in ("payment_method", "event_status", "listing_package", "listing_status"):
        op.execute(f"DROP TYPE IF EXISTS {enum_name}")
