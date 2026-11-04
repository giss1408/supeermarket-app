import datetime

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from tests.factories import (
    FlyerFactory,
    OfferFactory,
    PaymentMethodFactory,
    ProductFactory,
    RetailerFactory,
    StoreFactory,
)

pytestmark = pytest.mark.django_db


def build_content(retailer):
    """One row of every public kind, owned by ``retailer``."""
    flyer = FlyerFactory(retailer=retailer, status="published")
    product = ProductFactory(retailer=retailer)
    offer = OfferFactory(flyer=flyer, product=product)
    return {
        "flyer": flyer,
        "offer": offer,
        "store": StoreFactory(retailer=retailer),
        "category": product.category,
        "payment": PaymentMethodFactory(retailer=retailer, phone_number=f"+22507{retailer.pk:08d}"),
    }


def ids(path):
    resp = APIClient().get(path)
    assert resp.status_code == 200
    key = "phone_number" if path.endswith("payment-methods") else "id"
    return {r[key] for r in resp.data["results"]}


def current_status(path):
    return APIClient().get(path).status_code


def assert_hidden(c):
    assert c["flyer"].id not in ids("/api/v1/flyers")
    assert c["offer"].id not in ids("/api/v1/offers")
    assert c["store"].id not in ids("/api/v1/stores")
    assert c["category"].id not in ids("/api/v1/categories")
    assert c["payment"].phone_number not in ids("/api/v1/payment-methods")
    assert current_status(f"/api/v1/flyers/{c['flyer'].id}") == 404
    assert current_status(f"/api/v1/stores/{c['store'].id}") == 404
    assert current_status("/api/v1/flyers/current") == 404


def assert_visible(c):
    assert c["flyer"].id in ids("/api/v1/flyers")
    assert c["offer"].id in ids("/api/v1/offers")
    assert c["store"].id in ids("/api/v1/stores")
    assert c["category"].id in ids("/api/v1/categories")
    assert c["payment"].phone_number in ids("/api/v1/payment-methods")
    assert current_status(f"/api/v1/flyers/{c['flyer'].id}") == 200
    assert current_status(f"/api/v1/stores/{c['store'].id}") == 200
    assert current_status("/api/v1/flyers/current") == 200


@pytest.mark.parametrize("status", ["suspended", "pending"])
def test_non_active_retailer_content_is_hidden(status):
    retailer = RetailerFactory(status=status)
    assert_hidden(build_content(retailer))


def test_suspended_retailer_content_is_hidden():
    retailer = RetailerFactory()
    content = build_content(retailer)
    assert_visible(content)
    retailer.status = "suspended"
    retailer.save()
    assert_hidden(content)


def test_pending_retailer_content_is_hidden():
    retailer = RetailerFactory()
    content = build_content(retailer)
    retailer.status = "pending"
    retailer.save()
    assert_hidden(content)


def test_lapsed_but_active_retailer_content_stays_visible():
    retailer = RetailerFactory()
    content = build_content(retailer)
    sub = retailer.subscription
    sub.ends_at = timezone.now() - datetime.timedelta(days=3)
    sub.save()
    assert_visible(content)


def test_two_active_retailers_both_appear():
    a = build_content(RetailerFactory())
    b = build_content(RetailerFactory())
    assert_visible(a)
    assert_visible(b)
    assert {a["flyer"].id, b["flyer"].id} <= ids("/api/v1/flyers")


def test_hiding_one_retailer_keeps_the_other():
    a = build_content(RetailerFactory())
    hidden = RetailerFactory(status="suspended")
    b = build_content(hidden)
    assert_visible(a)
    assert b["flyer"].id not in ids("/api/v1/flyers")
