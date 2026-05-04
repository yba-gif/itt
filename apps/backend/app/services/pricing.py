"""Pricing — locked decisions per PRD §5.7."""

from __future__ import annotations

from app.models.listing import ListingPackage

# Amounts in CHF cents to avoid float rounding.
PACKAGE_AMOUNT_CENTS: dict[ListingPackage, int] = {
    ListingPackage.months_3: 60 * 100,
    ListingPackage.months_6: 100 * 100,
    ListingPackage.months_12: 180 * 100,
}

PACKAGE_DURATION_DAYS: dict[ListingPackage, int] = {
    ListingPackage.months_3: 90,
    ListingPackage.months_6: 180,
    ListingPackage.months_12: 365,
}

# First month free for all listings (new + v1 migrants), per PRD §5.7.
FIRST_MONTH_FREE_DAYS = 30


def package_label_tr(package: ListingPackage) -> str:
    return {
        ListingPackage.months_3: "3 ay — 60 CHF",
        ListingPackage.months_6: "6 ay — 100 CHF",
        ListingPackage.months_12: "12 ay — 180 CHF",
    }[package]


def package_amount_chf(package: ListingPackage) -> int:
    """Whole-CHF amount for display."""
    return PACKAGE_AMOUNT_CENTS[package] // 100
