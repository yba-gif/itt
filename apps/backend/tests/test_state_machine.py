"""Pure-Python tests for the Listing state machine (no DB required)."""

from __future__ import annotations

import pytest

from app.models.listing import Listing, ListingStatus


def make_listing(status: ListingStatus = ListingStatus.pending) -> Listing:
    listing = Listing(
        name="Test",
        directories=["saglik"],
        kantons=["ZH"],
        status=status,
    )
    return listing


def test_pending_can_transition_to_active():
    listing = make_listing(ListingStatus.pending)
    listing.transition_to(ListingStatus.active)
    assert listing.status == ListingStatus.active


def test_pending_can_transition_to_rejected():
    listing = make_listing(ListingStatus.pending)
    listing.transition_to(ListingStatus.rejected)
    assert listing.status == ListingStatus.rejected


def test_active_can_re_enter_pending_on_edit():
    listing = make_listing(ListingStatus.active)
    listing.transition_to(ListingStatus.pending)
    assert listing.status == ListingStatus.pending


def test_active_can_be_suspended():
    listing = make_listing(ListingStatus.active)
    listing.transition_to(ListingStatus.suspended)
    assert listing.status == ListingStatus.suspended


def test_rejected_is_terminal():
    listing = make_listing(ListingStatus.rejected)
    with pytest.raises(ValueError):
        listing.transition_to(ListingStatus.active)


def test_archived_is_terminal():
    listing = make_listing(ListingStatus.archived)
    with pytest.raises(ValueError):
        listing.transition_to(ListingStatus.active)


def test_pending_to_pending_is_illegal():
    listing = make_listing(ListingStatus.pending)
    with pytest.raises(ValueError):
        listing.transition_to(ListingStatus.pending)


def test_can_transition_to_predicate_matches_transition():
    listing = make_listing(ListingStatus.expired)
    assert listing.can_transition_to(ListingStatus.active)
    assert listing.can_transition_to(ListingStatus.archived)
    assert not listing.can_transition_to(ListingStatus.pending)
    assert not listing.can_transition_to(ListingStatus.rejected)
