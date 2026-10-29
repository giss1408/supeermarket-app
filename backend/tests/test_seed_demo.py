import datetime

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

    flyer = Flyer.objects.get()
    today = timezone.localdate()
    assert flyer.title == "Demo weekly flyer"
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
    assert Flyer.objects.get(title="Demo weekly flyer").status == Flyer.Status.DRAFT
