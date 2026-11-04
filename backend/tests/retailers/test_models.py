from datetime import timedelta

import pytest

from retailers.models import Payment, Retailer
from tests.retailers.conftest import make_retailer

pytestmark = pytest.mark.django_db

DAY = timedelta(days=1)


def test_can_publish_false_without_subscription():
    assert make_retailer().can_publish is False


def test_can_publish_true_when_active_and_unexpired():
    assert make_retailer(ends_in=30 * DAY).can_publish is True


def test_can_publish_false_when_lapsed():
    assert make_retailer(ends_in=-DAY).can_publish is False


def test_can_publish_false_when_suspended_even_if_unexpired():
    r = make_retailer(status=Retailer.Status.SUSPENDED, ends_in=30 * DAY)
    assert r.can_publish is False


def test_can_publish_false_when_pending():
    assert make_retailer(status=Retailer.Status.PENDING, ends_in=30 * DAY).can_publish is False


def test_payment_is_append_only():
    r = make_retailer()
    p = Payment(retailer=r, amount=10000, provider="wave", reference="R1", period_months=1)
    p.save()
    with pytest.raises(RuntimeError):
        p.save()


def test_expiring_and_lapsed_querysets():
    soon = make_retailer(slug="soon", ends_in=3 * DAY)
    make_retailer(slug="later", ends_in=30 * DAY)
    gone = make_retailer(slug="gone", ends_in=-DAY)
    make_retailer(slug="susp", status=Retailer.Status.SUSPENDED, ends_in=2 * DAY)
    make_retailer(slug="none")
    assert list(Retailer.objects.expiring()) == [soon]
    assert {r.slug for r in Retailer.objects.expiring(days=60)} == {"soon", "later"}
    assert list(Retailer.objects.lapsed()) == [gone]
