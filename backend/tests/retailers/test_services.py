from datetime import UTC, timedelta
from unittest import mock

import pytest
from django.utils import timezone

from retailers import services
from retailers.errors import DuplicatePayment
from retailers.models import Payment, Retailer, RetailerChange, Subscription
from retailers.services import _add_months
from tests.factories import UserFactory
from tests.retailers.conftest import make_retailer

pytestmark = pytest.mark.django_db


def pay(retailer, reference="R1", months=1, user=None, provider="wave"):
    return services.record_payment(
        retailer=retailer,
        amount=10000,
        provider=provider,
        reference=reference,
        period_months=months,
        confirmed_by=user,
    )


def test_add_months_clamps_day():
    from datetime import datetime

    assert _add_months(datetime(2026, 1, 31, tzinfo=UTC), 1) == datetime(2026, 2, 28, tzinfo=UTC)
    assert _add_months(datetime(2026, 11, 15, tzinfo=UTC), 3) == datetime(2027, 2, 15, tzinfo=UTC)


def test_record_payment_creates_subscription_from_now():
    r = make_retailer()
    before = timezone.now()
    payment = pay(r, months=2)
    sub = r.subscription
    assert before <= sub.starts_at <= timezone.now()
    assert sub.ends_at == _add_months(sub.starts_at, 2)
    assert payment.period_months == 2


def test_record_payment_extends_from_current_end_when_active():
    r = make_retailer(ends_in=timedelta(days=10))
    old_end = r.subscription.ends_at
    old_start = r.subscription.starts_at
    pay(r, months=3)
    sub = Subscription.objects.get(retailer=r)
    assert sub.ends_at == _add_months(old_end, 3)
    assert sub.starts_at == old_start


def test_record_payment_restarts_from_now_when_lapsed():
    r = make_retailer(ends_in=timedelta(days=-10))
    before = timezone.now()
    pay(r, months=1)
    sub = Subscription.objects.get(retailer=r)
    assert sub.starts_at >= before
    assert sub.ends_at == _add_months(sub.starts_at, 1)


def test_record_payment_does_not_activate_pending_retailer():
    r = make_retailer(status=Retailer.Status.PENDING)
    pay(r)
    r.refresh_from_db()
    assert r.status == Retailer.Status.PENDING
    assert r.can_publish is False


def test_record_payment_writes_one_audit_row():
    r = make_retailer()
    user = UserFactory()
    pay(r, user=user)
    change = RetailerChange.objects.get()
    assert change.action == RetailerChange.Action.PAYMENT
    assert change.changed_by == user
    assert change.changed_by_email == user.email
    assert change.retailer == r
    assert Payment.objects.get().confirmed_by == user


def test_duplicate_provider_reference_raises_duplicate_payment_and_changes_nothing():
    r = make_retailer(ends_in=timedelta(days=10))
    pay(r)
    end = Subscription.objects.get(retailer=r).ends_at
    with pytest.raises(DuplicatePayment):
        pay(r, months=5)
    assert Subscription.objects.get(retailer=r).ends_at == end
    assert Payment.objects.count() == 1
    assert RetailerChange.objects.count() == 1


def test_duplicate_detected_at_db_constraint():
    r = make_retailer()
    pay(r)
    with mock.patch.object(services, "_payment_exists", return_value=False):
        with pytest.raises(DuplicatePayment):
            pay(r)


def test_set_status_audits_and_rejects_pending():
    r = make_retailer(status=Retailer.Status.PENDING)
    user = UserFactory()
    services.set_status(r, Retailer.Status.ACTIVE, by=user)
    services.set_status(r, Retailer.Status.SUSPENDED, by=None)
    r.refresh_from_db()
    assert r.status == Retailer.Status.SUSPENDED
    actions = list(RetailerChange.objects.order_by("id").values_list("action", flat=True))
    assert actions == [RetailerChange.Action.ACTIVATED, RetailerChange.Action.SUSPENDED]
    with pytest.raises(ValueError):
        services.set_status(r, Retailer.Status.PENDING, by=user)
