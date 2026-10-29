import datetime
from decimal import Decimal

import pytest
from django.apps import apps
from django.core.management import CommandError, call_command
from django.utils import timezone
from rest_framework.test import APIClient

from offers.models import Flyer

MODELS = [
    "accounts.User",
    "accounts.LoyaltyCard",
    "catalog.Category",
    "catalog.Product",
    "offers.Flyer",
    "offers.Offer",
    "stores.Store",
    "stores.OpeningHours",
    "payments.PaymentMethod",
    "payments.PaymentMethodChange",
]
pytestmark = pytest.mark.django_db


@pytest.fixture
def debug(settings):
    settings.DEBUG = True


def counts():
    return {m: apps.get_model(m).objects.count() for m in MODELS}


def seed():
    call_command("seed_demo", stdout=_Out())


class _Out:
    def __init__(self):
        self.text = ""

    def write(self, msg):
        self.text += msg

    def flush(self):
        pass


def test_seed_demo_is_idempotent(debug):
    seed()
    first = counts()
    seed()
    assert counts() == first


def test_seed_demo_creates_expected_data(debug):
    seed()
    c = counts()
    assert c["catalog.Category"] == 6
    assert 20 <= c["catalog.Product"] <= 28
    assert c["offers.Flyer"] == 1
    assert 10 <= c["offers.Offer"] <= 14
    assert c["stores.Store"] == 5
    assert c["accounts.User"] == 2
    assert c["accounts.LoyaltyCard"] == 1
    assert c["payments.PaymentMethod"] == 3
    assert c["payments.PaymentMethodChange"] == 3

    flyer = Flyer.objects.get()
    today = timezone.localdate()
    assert flyer.title == "Prospectus de la semaine"
    assert flyer.status == Flyer.Status.PUBLISHED
    assert flyer.valid_from == today
    assert flyer.valid_to == today + datetime.timedelta(days=6)

    client = APIClient()
    res = client.get("/api/v1/flyers/current")
    assert res.status_code == 200
    assert res.json()["id"] == flyer.id
    offers = res.json()["offers"]
    assert any(o["old_price"] and o["badge_text"] for o in offers)

    stores = client.get("/api/v1/stores").json()["results"]
    assert len(stores) == 5
    hours = [client.get(f"/api/v1/stores/{s['id']}").json()["opening_hours"] for s in stores]
    assert all(hours)
    assert any(len(h) == 6 for h in hours)

    login = client.post(
        "/api/v1/auth/login",
        {"email": "staff@example.com", "password": "demo-staff-pass-123"},
        format="json",
    )
    assert login.status_code == 200
    staff = APIClient()
    staff.credentials(HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}")
    assert staff.get("/api/v1/staff/flyers").status_code == 200
    assert client.get("/api/v1/staff/flyers").status_code in (401, 403)

    from accounts.models import User

    customer = User.objects.get(email="customer@example.com")
    assert customer.card.number
    assert not hasattr(User.objects.get(email="staff@example.com"), "card")


def test_seed_demo_refuses_when_debug_false(settings):
    settings.DEBUG = False
    with pytest.raises(CommandError):
        seed()
    assert all(n == 0 for n in counts().values())


def test_seed_demo_rerun_after_flyer_dates_passed_does_not_crash(debug):
    seed()
    past = timezone.localdate() - datetime.timedelta(days=30)
    Flyer.objects.update(valid_from=past, valid_to=past + datetime.timedelta(days=6))
    first = counts()
    seed()
    assert counts() == first
    flyer = Flyer.objects.get()
    today = timezone.localdate()
    assert flyer.status == Flyer.Status.PUBLISHED
    assert flyer.valid_from <= today <= flyer.valid_to


def test_seed_demo_password_from_env(debug, monkeypatch):
    monkeypatch.setenv("DEMO_STAFF_PASSWORD", "another-Strong-pw-77")
    monkeypatch.setenv("DEMO_CUSTOMER_PASSWORD", "customer-Strong-pw-88")
    seed()
    client = APIClient()
    ok = client.post(
        "/api/v1/auth/login",
        {"email": "staff@example.com", "password": "another-Strong-pw-77"},
        format="json",
    )
    assert ok.status_code == 200
    old = client.post(
        "/api/v1/auth/login",
        {"email": "staff@example.com", "password": "demo-staff-pass-123"},
        format="json",
    )
    assert old.status_code == 401
    ok = client.post(
        "/api/v1/auth/login",
        {"email": "customer@example.com", "password": "customer-Strong-pw-88"},
        format="json",
    )
    assert ok.status_code == 200


def test_seed_demo_leaves_flyer_draft_when_another_flyer_blocks_today(debug):
    from tests.factories import FlyerFactory, OfferFactory

    other = FlyerFactory(title="Other", status="draft")
    OfferFactory(flyer=other)
    from offers.services import publish_flyer

    publish_flyer(other)
    seed()  # must warn, not crash
    assert Flyer.objects.get(title="Prospectus de la semaine").status == Flyer.Status.DRAFT


def test_seed_demo_prices_are_whole_xof_amounts(debug):
    from offers.models import Offer

    seed()
    offers = list(Offer.objects.all())
    assert offers
    for offer in offers:
        assert offer.price == offer.price.quantize(Decimal("1"))
        assert Decimal("500") <= offer.price <= Decimal("25000")
        assert offer.price % 5 == 0
        if offer.old_price is not None:
            assert offer.old_price == offer.old_price.quantize(Decimal("1"))
            assert offer.old_price % 5 == 0
            assert offer.old_price > offer.price


def test_seed_demo_stores_are_in_cote_divoire(debug):
    from stores.models import Store

    seed()
    stores = list(Store.objects.all())
    assert len(stores) == 5
    assert {s.city for s in stores} <= {"Abidjan", "Bouaké"}
    for store in stores:
        assert Decimal("4") <= store.latitude <= Decimal("11")
        assert Decimal("-9") <= store.longitude <= Decimal("-2")


def test_seed_demo_payment_methods_are_public_and_fake(debug):
    seed()
    res = APIClient().get("/api/v1/payment-methods")
    assert res.status_code == 200
    rows = res.json()["results"]
    assert {r["provider"]: r["phone_number"] for r in rows} == {
        "wave": "+2250100000001",
        "orange_money": "+2250700000002",
        "mtn_momo": "+2250500000003",
    }
    assert all(r["display_name"] and r["instructions"] for r in rows)


def test_seed_demo_rerun_updates_payment_methods_without_audit_duplicates(debug):
    from payments.models import PaymentMethod, PaymentMethodChange

    seed()
    assert PaymentMethodChange.objects.count() == 3
    seed()
    assert PaymentMethodChange.objects.count() == 3
    PaymentMethod.objects.filter(provider="wave").update(phone_number="+2250100000099")
    seed()
    assert PaymentMethod.objects.count() == 3
    assert PaymentMethod.objects.get(provider="wave").phone_number == "+2250100000001"
    assert PaymentMethodChange.objects.count() == 4


def test_seed_demo_uses_french_catalog(debug):
    from catalog.models import Category

    seed()
    names = set(Category.objects.values_list("name", flat=True))
    assert "Fruits et légumes" in names and "Boissons" in names
