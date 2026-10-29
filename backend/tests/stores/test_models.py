import datetime
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from stores.models import Store
from tests.factories import OpeningHoursFactory, StoreFactory

pytestmark = pytest.mark.django_db


def test_opening_hours_unique_per_weekday():
    store = StoreFactory()
    OpeningHoursFactory(store=store, weekday=0)
    with pytest.raises(IntegrityError), transaction.atomic():
        OpeningHoursFactory(store=store, weekday=0)
    OpeningHoursFactory(store=store, weekday=1)
    OpeningHoursFactory(weekday=0)


@pytest.mark.parametrize("opens,closes", [((20, 0), (8, 0)), ((8, 0), (8, 0))])
def test_opening_hours_opens_before_closes(opens, closes):
    with pytest.raises(IntegrityError), transaction.atomic():
        OpeningHoursFactory(opens=datetime.time(*opens), closes=datetime.time(*closes))


def test_weekday_range_validated():
    hours = OpeningHoursFactory.build(weekday=7)
    with pytest.raises(ValidationError):
        hours.full_clean(exclude=["store"])


@pytest.mark.parametrize(
    "field,value",
    [
        ("latitude", Decimal("90.5")),
        ("latitude", Decimal("-90.5")),
        ("longitude", Decimal("180.5")),
        ("longitude", Decimal("-180.5")),
    ],
)
def test_latitude_longitude_range_validated(field, value):
    store = StoreFactory.build(**{field: value})
    with pytest.raises(ValidationError) as exc:
        store.full_clean()
    assert field in exc.value.message_dict


def test_latitude_longitude_valid_extremes():
    store = StoreFactory.build(latitude=Decimal("-90"), longitude=Decimal("180"))
    store.full_clean()
    store.save()
    assert Store.objects.get(pk=store.pk).longitude == Decimal("180.000000")
