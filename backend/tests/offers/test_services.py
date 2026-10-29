import datetime

import pytest
from django.core.exceptions import ValidationError

from offers.services import publish_flyer, unpublish_flyer
from tests.factories import FlyerFactory, OfferFactory

pytestmark = pytest.mark.django_db

D = datetime.date


def _flyer(start, end, status="draft", offers=True):
    flyer = FlyerFactory(valid_from=start, valid_to=end, status=status)
    if offers:
        OfferFactory(flyer=flyer)
    return flyer


def test_publish_requires_at_least_one_offer():
    flyer = _flyer(D(2026, 11, 1), D(2026, 11, 7), offers=False)
    with pytest.raises(ValidationError):
        publish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_publish_rejects_overlap_with_published_flyer():
    _flyer(D(2026, 11, 1), D(2026, 11, 7), status="published")
    flyer = _flyer(D(2026, 11, 5), D(2026, 11, 12))
    with pytest.raises(ValidationError):
        publish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_adjacent_flyers_do_not_overlap():
    _flyer(D(2026, 10, 27), D(2026, 11, 2), status="published")
    flyer = _flyer(D(2026, 11, 3), D(2026, 11, 9))
    assert publish_flyer(flyer).status == "published"


def test_flyers_sharing_a_boundary_day_overlap():
    _flyer(D(2026, 10, 27), D(2026, 11, 2), status="published")
    flyer = _flyer(D(2026, 11, 2), D(2026, 11, 9))
    with pytest.raises(ValidationError):
        publish_flyer(flyer)


def test_publish_is_idempotent():
    flyer = _flyer(D(2026, 11, 1), D(2026, 11, 7))
    publish_flyer(flyer)
    again = publish_flyer(flyer)
    assert again.status == "published"
    flyer.refresh_from_db()
    assert flyer.status == "published"


def test_publish_ignores_draft_flyers_when_checking_overlap():
    _flyer(D(2026, 11, 1), D(2026, 11, 7), status="draft")
    flyer = _flyer(D(2026, 11, 3), D(2026, 11, 9))
    assert publish_flyer(flyer).status == "published"


def test_unpublish_sets_draft():
    flyer = _flyer(D(2026, 11, 1), D(2026, 11, 7), status="published")
    assert unpublish_flyer(flyer).status == "draft"
    flyer.refresh_from_db()
    assert flyer.status == "draft"
    assert unpublish_flyer(flyer).status == "draft"


def test_db_rejects_overlapping_published_flyers():
    from django.db import IntegrityError, transaction

    _flyer(D(2026, 11, 1), D(2026, 11, 7), status="published", offers=False)
    with pytest.raises(IntegrityError), transaction.atomic():
        FlyerFactory(valid_from=D(2026, 11, 7), valid_to=D(2026, 11, 9), status="published")


def test_db_allows_adjacent_published_and_overlapping_drafts():
    FlyerFactory(valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 2), status="published")
    FlyerFactory(valid_from=D(2026, 11, 3), valid_to=D(2026, 11, 5), status="published")
    FlyerFactory(valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 5), status="draft")


def test_publish_race_loser_gets_validation_error(monkeypatch):
    from offers import services

    flyer = _flyer(D(2026, 11, 3), D(2026, 11, 9))
    FlyerFactory(valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 4), status="published")
    monkeypatch.setattr(services, "_find_overlap", lambda f: None)
    with pytest.raises(ValidationError):
        publish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_admin_dates_readonly_only_when_published():
    from django.contrib import admin as dj_admin

    from offers.models import Flyer

    ma = dj_admin.site._registry[Flyer]
    draft = FlyerFactory()
    pub = FlyerFactory(status="published", valid_from=D(2027, 1, 1), valid_to=D(2027, 1, 2))
    assert "valid_from" not in ma.get_readonly_fields(None, draft)
    assert "valid_from" not in ma.get_readonly_fields(None, None)
    assert {"valid_from", "valid_to", "status"} <= set(ma.get_readonly_fields(None, pub))
