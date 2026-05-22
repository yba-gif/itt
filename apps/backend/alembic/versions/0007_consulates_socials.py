"""Add consulates + socials tables, seed from current iOS-hardcoded values.

Migration also imports a single admin-curated dataset so first deploy lands
with the exact data already shown in TestFlight build 46 — no in-app gap.

Revision ID: 0007_consulates_socials
Revises: 0006_ai_questions
Create Date: 2026-05-22
"""

from __future__ import annotations

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0007_consulates_socials"
down_revision: Union[str, None] = "0006_ai_questions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- consulates table ----
    op.create_table(
        "consulates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("city", sa.String(60), nullable=False),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("address", sa.String(256), nullable=False),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("phone_display", sa.String(32), nullable=False),
        sa.Column("email", sa.String(320), nullable=True),
        sa.Column("website", sa.String(512), nullable=False),
        sa.Column("hours_summary", sa.String(120), nullable=False),
        sa.Column("hours_detail", sa.Text, nullable=True),
        sa.Column("consul_name", sa.String(120), nullable=True),
        sa.Column("consul_title", sa.String(120), nullable=False),
        sa.Column("consul_photo_url", sa.String(1024), nullable=True),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_consulates_sort_order", "consulates", ["sort_order"])

    # ---- socials table ----
    op.create_table(
        "socials",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("label", sa.String(40), nullable=False),
        sa.Column("system_icon", sa.String(60), nullable=False),
        sa.Column("url", sa.String(512), nullable=False),
        sa.Column("tint_hex", sa.String(7), nullable=False, server_default="#B82030"),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_socials_sort_order", "socials", ["sort_order"])

    # ---- seed consulates (matches iOS BilgiTab build 46) ----
    consulates_t = sa.table(
        "consulates",
        sa.column("id", postgresql.UUID(as_uuid=True)),
        sa.column("city", sa.String),
        sa.column("title", sa.String),
        sa.column("address", sa.String),
        sa.column("phone", sa.String),
        sa.column("phone_display", sa.String),
        sa.column("email", sa.String),
        sa.column("website", sa.String),
        sa.column("hours_summary", sa.String),
        sa.column("hours_detail", sa.Text),
        sa.column("consul_name", sa.String),
        sa.column("consul_title", sa.String),
        sa.column("consul_photo_url", sa.String),
        sa.column("sort_order", sa.Integer),
    )

    op.bulk_insert(
        consulates_t,
        [
            {
                "id": uuid4(),
                "city": "Bern",
                "title": "Türkiye Büyükelçiliği",
                "address": "Villastrasse 32, 3006 Bern",
                "phone": "+41313592200",
                "phone_display": "+41 31 359 22 00",
                "email": "embassy.berne@mfa.gov.tr",
                "website": "https://bern-be.mfa.gov.tr",
                "hours_summary": "Pzt - Cuma\n09:00 - 12:00 / 13:00 - 18:00",
                "hours_detail": "Konsolosluk işlemleri için randevu zorunludur. Randevu için web sitesini ziyaret edin.",
                "consul_name": "Şebnem İncesu",
                "consul_title": "T.C. Bern Büyükelçisi",
                "consul_photo_url": "https://bern-be.mfa.gov.tr/Content/assets/consulate/images/localCache//60/866246c9-a693-427a-aab8-02ad0e68de29.png",
                "sort_order": 10,
            },
            {
                "id": uuid4(),
                "city": "Zürich",
                "title": "Türkiye Cumhuriyeti Başkonsolosluğu",
                "address": "Basteiplatz 2, 8001 Zürich",
                "phone": "+41442016400",
                "phone_display": "+41 44 201 64 00",
                "email": "konsolosluk.zurih@mfa.gov.tr",
                "website": "https://zurih-bk.mfa.gov.tr",
                "hours_summary": "Pzt - Cuma\n09:00 - 12:00 / 13:00 - 18:00",
                "hours_detail": "Konsolosluk işlemleri için randevu zorunludur.",
                "consul_name": "Fazlı Çorman",
                "consul_title": "T.C. Zürih Başkonsolosu",
                "consul_photo_url": "https://zurih-bk.mfa.gov.tr/Content/assets/consulate/images/localCache//60/841b03b0-dcaf-48a4-b221-469bddb709be.png",
                "sort_order": 20,
            },
            {
                "id": uuid4(),
                "city": "Cenevre",
                "title": "Türkiye Cumhuriyeti Başkonsolosluğu",
                "address": "Avenue Soret 4, 1203 Genève",
                "phone": "+41227321600",
                "phone_display": "+41 22 732 16 00",
                "email": "konsolosluk.cenevre@mfa.gov.tr",
                "website": "https://cenevre-bk.mfa.gov.tr",
                "hours_summary": "Pzt - Cuma\n09:00 - 12:00 / 13:00 - 18:00",
                "hours_detail": "Konsolosluk işlemleri için randevu zorunludur.",
                "consul_name": "Salih Boğaç Güldere",
                "consul_title": "T.C. Cenevre Başkonsolosu",
                "consul_photo_url": "https://cenevre-bk.mfa.gov.tr/Content/assets/consulate/images/localCache//60/1b429194-368f-480f-a07f-f1b37021cdf9.png",
                "sort_order": 30,
            },
        ],
    )

    # ---- seed socials (matches iOS BilgiTab build 46) ----
    socials_t = sa.table(
        "socials",
        sa.column("id", postgresql.UUID(as_uuid=True)),
        sa.column("label", sa.String),
        sa.column("system_icon", sa.String),
        sa.column("url", sa.String),
        sa.column("tint_hex", sa.String),
        sa.column("sort_order", sa.Integer),
    )

    op.bulk_insert(
        socials_t,
        [
            {
                "id": uuid4(),
                "label": "Facebook",
                "system_icon": "f.square.fill",
                "url": "https://www.facebook.com/itt.tgs",
                "tint_hex": "#1A5CC8",
                "sort_order": 10,
            },
            {
                "id": uuid4(),
                "label": "X",
                "system_icon": "xmark",
                "url": "https://x.com/isvicreturkitt",
                "tint_hex": "#000000",
                "sort_order": 20,
            },
            {
                "id": uuid4(),
                "label": "Instagram",
                "system_icon": "camera.fill",
                "url": "https://www.instagram.com/isvicreturktoplumu_itt/",
                "tint_hex": "#C82980",
                "sort_order": 30,
            },
            {
                "id": uuid4(),
                "label": "Web",
                "system_icon": "globe",
                "url": "https://tgs-itt.ch/",
                "tint_hex": "#B82030",
                "sort_order": 40,
            },
            {
                "id": uuid4(),
                "label": "E-posta",
                "system_icon": "envelope.fill",
                "url": "mailto:info@tgs-itt.ch",
                "tint_hex": "#1B2734",
                "sort_order": 50,
            },
        ],
    )


def downgrade() -> None:
    op.drop_index("ix_socials_sort_order", table_name="socials")
    op.drop_table("socials")
    op.drop_index("ix_consulates_sort_order", table_name="consulates")
    op.drop_table("consulates")
