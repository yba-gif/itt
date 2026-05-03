#!/usr/bin/env python3
"""Convenience entry point — invokes app.seed.run from outside the container.

Usage:
    cd apps/backend && python ../../scripts/seed-db.py
"""

from __future__ import annotations

import asyncio
import os
import sys

# Make `app` importable when run from repo root.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "apps", "backend"))

from app.seed.run import main  # noqa: E402


if __name__ == "__main__":
    asyncio.run(main())
