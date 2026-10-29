import datetime
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models import ProtectedError

from offers.models import Flyer, Offer
from tests.factories import OfferFactory

pytestmark = pytest.mark.django_db

D = datetime.date


def test_flyer_rejects_from_after_to():
    flyer = Flyer(title="x", valid_from=D(2026, 11, 5), valid_to=D(2026, 11, 1))
    with pytest.raises(ValidationError):
        flyer.clean()
    with pytest.raises(IntegrityError), transaction.atomic():
        Flyer.objects.create(title="x", valid_from=D(2026, 11, 5), valid_to=D(2026, 11, 1))


def test_price_is_decimal():
    offer = OfferFactory(price=Decimal("1.99"), old_price=Decimal("2.49"))
    offer = Offer.objects.get(pk=offer.pk)
    assert isinstance(offer.price, Decimal)
    assert offer.price == Decimal("1.99")
    assert offer.old_price == Decimal("2.49")


@pytest.mark.parametrize("price", [Decimal("0"), Decimal("-1.00")])
def test_offer_price_must_be_positive(price):
    with pytest.raises(IntegrityError), transaction.atomic():
        OfferFactory(price=price)


@pytest.mark.parametrize("old_price", [Decimal("1.99"), Decimal("1.00")])
def test_offer_old_price_must_exceed_price(old_price):
    with pytest.raises(IntegrityError), transaction.atomic():
        OfferFactory(price=Decimal("1.99"), old_price=old_price)


def test_offer_validity_dates_must_be_ordered():
    with pytest.raises(IntegrityError), transaction.atomic():
        OfferFactory(valid_from=D(2026, 11, 5), valid_to=D(2026, 11, 1))
    OfferFactory(valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 1))
    OfferFactory(valid_from=None, valid_to=None)


def test_product_protected_from_delete_when_offered():
    offer = OfferFactory()
    with pytest.raises(ProtectedError):
        offer.product.delete()
