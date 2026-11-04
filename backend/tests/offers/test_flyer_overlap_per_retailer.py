import datetime

import pytest
from django.db import IntegrityError, transaction

from tests.factories import FlyerFactory, RetailerFactory

pytestmark = pytest.mark.django_db

D = datetime.date


def _published(retailer, start, end):
    return FlyerFactory(retailer=retailer, valid_from=start, valid_to=end, status="published")


def test_same_retailer_overlapping_published_flyers_rejected():
    retailer = RetailerFactory()
    _published(retailer, D(2026, 1, 1), D(2026, 1, 7))
    with pytest.raises(IntegrityError), transaction.atomic():
        _published(retailer, D(2026, 1, 7), D(2026, 1, 14))


def test_different_retailers_may_overlap():
    _published(RetailerFactory(), D(2026, 1, 1), D(2026, 1, 7))
    _published(RetailerFactory(), D(2026, 1, 1), D(2026, 1, 7))
