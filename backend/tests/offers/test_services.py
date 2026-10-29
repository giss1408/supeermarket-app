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
