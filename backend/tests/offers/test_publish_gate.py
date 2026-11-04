import datetime

import pytest
from django.contrib.messages import get_messages
from django.urls import reverse
from django.utils import timezone

from offers.services import publish_flyer, unpublish_flyer
from retailers.errors import SubscriptionRequired
from tests.factories import FlyerFactory, OfferFactory, RetailerFactory, StaffFactory

pytestmark = pytest.mark.django_db


def _flyer(retailer, **kw):
    flyer = FlyerFactory(retailer=retailer, **kw)
    OfferFactory(flyer=flyer)
    return flyer


def test_publish_allowed_when_active_and_subscribed():
    flyer = _flyer(RetailerFactory())
    publish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "published"


def test_publish_blocked_when_no_subscription():
    retailer = RetailerFactory()
    retailer.subscription.delete()
    flyer = _flyer(retailer)
    with pytest.raises(SubscriptionRequired):
        publish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_publish_blocked_when_lapsed():
    retailer = RetailerFactory()
    retailer.subscription.ends_at = timezone.now() - datetime.timedelta(days=1)
    retailer.subscription.save()
    with pytest.raises(SubscriptionRequired):
        publish_flyer(_flyer(retailer))


@pytest.mark.parametrize("status", ["suspended", "pending"])
def test_publish_blocked_when_not_active(status):
    retailer = RetailerFactory()
    retailer.status = status
    retailer.save()
    with pytest.raises(SubscriptionRequired):
        publish_flyer(_flyer(retailer))


def test_gate_runs_before_offers_check():
    retailer = RetailerFactory()
    retailer.subscription.delete()
    with pytest.raises(SubscriptionRequired):
        publish_flyer(FlyerFactory(retailer=retailer))  # no offers


def _lapse(retailer):
    retailer.subscription.ends_at = timezone.now() - datetime.timedelta(days=1)
    retailer.subscription.save()


def test_unpublish_still_allowed_when_lapsed():
    retailer = RetailerFactory()
    flyer = _flyer(retailer, status="published")
    _lapse(retailer)
    unpublish_flyer(flyer)
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_already_published_flyer_stays_published_after_lapse():
    retailer = RetailerFactory()
    flyer = _flyer(retailer, status="published")
    _lapse(retailer)
    flyer.refresh_from_db()
    assert flyer.status == "published"


def test_staff_api_publish_returns_403_subscription_required(client):
    from rest_framework.test import APIClient

    retailer = RetailerFactory()
    flyer = _flyer(retailer)
    _lapse(retailer)
    api = APIClient()
    api.force_authenticate(StaffFactory(retailer=retailer))
    resp = api.post(f"/api/v1/staff/flyers/{flyer.id}/publish")
    assert resp.status_code == 403
    body = resp.json()
    assert set(body) == {"code", "detail", "fields"}
    assert body["code"] == "subscription_required"
    assert body["fields"] == {}
    assert body["detail"]
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_admin_publish_action_reports_error(client):
    retailer = RetailerFactory()
    retailer.subscription.delete()
    flyer = _flyer(retailer)
    client.force_login(StaffFactory(is_staff=True, is_superuser=True))
    resp = client.post(
        reverse("admin:offers_flyer_changelist"),
        {"action": "publish_selected", "_selected_action": [flyer.pk]},
    )
    assert resp.status_code == 302
    msgs = list(get_messages(resp.wsgi_request))
    assert len(msgs) == 1 and msgs[0].level_tag == "error"
    assert flyer.title in msgs[0].message
    flyer.refresh_from_db()
    assert flyer.status == "draft"


D = datetime.date


def _overlap_flyer(retailer, **kw):
    return _flyer(retailer, valid_from=D(2026, 1, 1), valid_to=D(2026, 1, 7), **kw)


def test_different_retailers_can_publish_identical_overlapping_flyers():
    a = _overlap_flyer(RetailerFactory())
    b = _overlap_flyer(RetailerFactory())
    publish_flyer(a)
    publish_flyer(b)
    b.refresh_from_db()
    assert b.status == "published"


def test_same_retailer_overlap_still_rejected_naming_own_flyer():
    from django.core.exceptions import ValidationError

    retailer = RetailerFactory()
    first = _overlap_flyer(retailer, title="Own Flyer Alpha")
    second = _overlap_flyer(retailer)
    publish_flyer(first)
    with pytest.raises(ValidationError) as exc:
        publish_flyer(second)
    assert "Own Flyer Alpha" in str(exc.value)


def test_overlap_error_never_leaks_other_retailers_flyer_title():
    from django.core.exceptions import ValidationError

    a = _overlap_flyer(RetailerFactory(), title="SecretTitle-RetailerA-xyz")
    publish_flyer(a)
    retailer_b = RetailerFactory()
    first = _overlap_flyer(retailer_b, title="B Own")
    second = _overlap_flyer(retailer_b)
    publish_flyer(first)
    with pytest.raises(ValidationError) as exc:
        publish_flyer(second)
    assert "SecretTitle-RetailerA-xyz" not in str(exc.value)
    assert "B Own" in str(exc.value)
