"""Kanton — Swiss canton reference data (26 rows)."""

from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Kanton(Base):
    __tablename__ = "kantons"

    code: Mapped[str] = mapped_column(String(2), primary_key=True)
    name_tr: Mapped[str] = mapped_column(String(64), nullable=False)
    name_de: Mapped[str] = mapped_column(String(64), nullable=False)
