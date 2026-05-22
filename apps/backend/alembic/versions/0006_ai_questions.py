"""Add ai_questions table for admin's AI question log.

Revision ID: 0006_ai_questions
Revises: 0005_search_directories
Create Date: 2026-05-22
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006_ai_questions"
down_revision: Union[str, None] = "0005_search_directories"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ai_questions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("question", sa.Text, nullable=False),
        sa.Column("response_chars", sa.Integer, nullable=False, server_default="0"),
        sa.Column("lang", sa.String(8), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_ai_questions_user_id", "ai_questions", ["user_id"])
    op.create_index("ix_ai_questions_created_at", "ai_questions", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_ai_questions_created_at", table_name="ai_questions")
    op.drop_index("ix_ai_questions_user_id", table_name="ai_questions")
    op.drop_table("ai_questions")
