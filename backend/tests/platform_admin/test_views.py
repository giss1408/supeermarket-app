import datetime

import pytest
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from payments.models import PaymentMethod
from platform_admin.forms import PaymentForm, RetailerCreateForm
from retailers.models import Payment, Retailer, RetailerChange, Subscription
from tests.factories import (
    FlyerFactory,
    PlatformAdminFactory,
    RetailerFactory,
    StaffFactory,
)

pytestmark = pytest.mark.django_db

User = get_user_model()
GOOD_PW = "Zx9!kLmQ72vr"


@pytest.fixture
def admin():
    return PlatformAdminFactory()


@pytest.fixture
def client(admin):
    c = Client()
    c.force_login(admin)
    return c


def _set_end(retailer, delta):
    Subscription.objects.filter(retailer=retailer).update(ends_at=timezone.now() + delta)


def test_list_filters_expiring_and_lapsed(client):
    ok = RetailerFactory(name="Okshop")
    expiring = RetailerFactory(name="Expshop")
    _set_end(expiring, datetime.timedelta(days=3))
    lapsed = RetailerFactory(name="Lapshop")
    _set_end(lapsed, datetime.timedelta(days=-1))
    pending = RetailerFactory(name="Pendshop", status="pending")
    url = reverse("platform:retailer_list")

    def names(flt):
        body = client.get(url, {"filter": flt}).content.decode()
        return {r.name for r in (ok, expiring, lapsed, pending) if r.name in body}

    assert names("expiring") == {"Expshop"}
    assert names("lapsed") == {"Lapshop"}
    assert names("pending") == {"Pendshop"}
    assert names("active") == {"Okshop", "Expshop", "Lapshop"}
    assert names("bogus") == {"Okshop", "Expshop", "Lapshop", "Pendshop"}
    assert names("") == {"Okshop", "Expshop", "Lapshop", "Pendshop"}


def test_create_retailer_creates_pending_retailer_and_staff_user(client):
    resp = client.post(
        reverse("platform:retailer_create"),
        {"name": "Super Marché", "staff_email": "Boss@Shop.com", "staff_password": GOOD_PW},
    )
    retailer = Retailer.objects.get(name="Super Marché")
    assert resp.status_code == 302
    assert resp["Location"] == reverse("platform:retailer_detail", args=[retailer.pk])
    assert retailer.status == "pending"
    assert retailer.slug == "super-marche"
    user = User.objects.get(email="boss@shop.com")
    assert user.role == "retailer_staff"
    assert user.retailer == retailer
    assert user.check_password(GOOD_PW)


def test_create_retailer_makes_slug_unique(client):
    RetailerFactory(name="Dup", slug="dup")
    client.post(
        reverse("platform:retailer_create"),
        {"name": "Dup", "staff_email": "a@shop.com", "staff_password": GOOD_PW},
    )
    assert Retailer.objects.filter(name="Dup").count() == 2
    assert Retailer.objects.filter(slug="dup-2").exists()


def test_create_retailer_rejects_existing_email(client):
    StaffFactory(email="taken@shop.com")
    before = Retailer.objects.count()
    resp = client.post(
        reverse("platform:retailer_create"),
        {"name": "New", "staff_email": "TAKEN@shop.com", "staff_password": GOOD_PW},
    )
    assert resp.status_code == 200
    assert "staff_email" in resp.context["form"].errors
    assert Retailer.objects.count() == before


def test_create_retailer_rejects_weak_password(client):
    resp = client.post(
        reverse("platform:retailer_create"),
        {"name": "New", "staff_email": "n@shop.com", "staff_password": "1234"},
    )
    assert resp.status_code == 200
    assert "staff_password" in resp.context["form"].errors
    assert not Retailer.objects.filter(name="New").exists()


def test_create_form_rolls_back_retailer_when_user_creation_fails(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("x")

    monkeypatch.setattr(User.objects, "create_user", boom)
    form = RetailerCreateForm(
        {"name": "Rb", "staff_email": "rb@shop.com", "staff_password": GOOD_PW}
    )
    assert form.is_valid()
    with pytest.raises(RuntimeError):
        form.save()
    assert not Retailer.objects.filter(name="Rb").exists()


def _pay(client, retailer, **over):
    data = {"amount": 50000, "provider": "wave", "reference": "TX1", "period_months": 1} | over
    return client.post(reverse("platform:payment_create", args=[retailer.pk]), data)


def test_record_payment_extends_subscription_and_shows_in_history(client):
    retailer = RetailerFactory()
    old_end = retailer.subscription.ends_at
    resp = _pay(client, retailer)
    assert resp.status_code == 302
    retailer.subscription.refresh_from_db()
    assert retailer.subscription.ends_at > old_end
    assert Payment.objects.filter(retailer=retailer, reference="TX1").exists()
    page = client.get(reverse("platform:retailer_detail", args=[retailer.pk])).content.decode()
    assert "TX1" in page
    assert retailer.subscription.ends_at.strftime("%d/%m/%Y") in page


def test_payment_history_newest_first(client):
    retailer = RetailerFactory()
    _pay(client, retailer, reference="FIRST-REF")
    _pay(client, retailer, reference="SECOND-REF")
    page = client.get(reverse("platform:retailer_detail", args=[retailer.pk])).content.decode()
    assert page.index("SECOND-REF") < page.index("FIRST-REF")


def test_record_payment_duplicate_reference_shows_error(client):
    retailer = RetailerFactory()
    _pay(client, retailer)
    resp = _pay(client, retailer)
    assert resp.status_code == 200
    assert "reference" in resp.context["form"].errors
    assert Payment.objects.filter(retailer=retailer).count() == 1


def test_record_payment_pending_retailer_stays_pending(client):
    retailer = RetailerFactory(status="pending")
    assert _pay(client, retailer).status_code == 302
    retailer.refresh_from_db()
    assert retailer.status == "pending"
    assert retailer.subscription.ends_at > timezone.now()


def test_record_payment_for_retailer_without_subscription(client):
    retailer = RetailerFactory(status="pending")
    Subscription.objects.filter(retailer=retailer).delete()
    assert _pay(client, retailer).status_code == 302
    assert Subscription.objects.filter(retailer=retailer).exists()


def test_payment_form_rejects_zero_amount():
    form = PaymentForm({"amount": 0, "provider": "wave", "reference": "R", "period_months": 1})
    assert not form.is_valid()
    assert "amount" in form.errors


def test_payment_form_rejects_zero_months():
    form = PaymentForm({"amount": 100, "provider": "wave", "reference": "R", "period_months": 0})
    assert not form.is_valid()
    assert "period_months" in form.errors


def test_payment_form_rejects_too_many_months_and_bad_provider():
    form = PaymentForm({"amount": 100, "provider": "wave", "reference": "R", "period_months": 37})
    assert "period_months" in PaymentForm(form.data).errors
    bad = PaymentForm({"amount": 100, "provider": "cash", "reference": "R", "period_months": 1})
    assert "provider" in bad.errors
    assert {v for v, _ in PaymentForm().fields["provider"].choices} == set(
        PaymentMethod.Provider.values
    )


def test_payment_page_renders(client):
    retailer = RetailerFactory()
    resp = client.get(reverse("platform:payment_create", args=[retailer.pk]))
    assert resp.status_code == 200


def test_activate_and_suspend_write_audit_rows(client, admin):
    retailer = RetailerFactory(status="pending")
    assert client.post(reverse("platform:retailer_activate", args=[retailer.pk])).status_code == 302
    retailer.refresh_from_db()
    assert retailer.status == "active"
    client.post(reverse("platform:retailer_suspend", args=[retailer.pk]))
    retailer.refresh_from_db()
    assert retailer.status == "suspended"
    actions = list(
        RetailerChange.objects.filter(retailer=retailer).values_list("action", "changed_by")
    )
    assert sorted(actions) == sorted([("activated", admin.pk), ("suspended", admin.pk)])


def test_activate_already_active_and_suspend_already_suspended_are_graceful(client):
    active = RetailerFactory(status="active")
    resp = client.post(reverse("platform:retailer_activate", args=[active.pk]), follow=True)
    assert resp.status_code == 200
    assert not RetailerChange.objects.filter(retailer=active).exists()
    suspended = RetailerFactory(status="suspended")
    resp = client.post(reverse("platform:retailer_suspend", args=[suspended.pk]), follow=True)
    assert resp.status_code == 200
    assert not RetailerChange.objects.filter(retailer=suspended).exists()


def test_activate_and_suspend_are_post_only(client):
    retailer = RetailerFactory()
    for name in ("retailer_activate", "retailer_suspend"):
        assert client.get(reverse(f"platform:{name}", args=[retailer.pk])).status_code == 405


def test_detail_shows_staff_and_buttons(client):
    retailer = RetailerFactory()
    staff = StaffFactory(retailer=retailer)
    page = client.get(reverse("platform:retailer_detail", args=[retailer.pk])).content.decode()
    assert staff.email in page
    assert reverse("platform:retailer_activate", args=[retailer.pk]) in page
    assert reverse("platform:retailer_suspend", args=[retailer.pk]) in page


def test_detail_unknown_retailer_404(client):
    assert client.get(reverse("platform:retailer_detail", args=[999999])).status_code == 404


def test_create_page_renders(client):
    assert client.get(reverse("platform:retailer_create")).status_code == 200


def test_suspended_retailer_flyers_vanish_from_public_api(client):
    retailer = RetailerFactory(status="active")
    flyer = FlyerFactory(retailer=retailer, status="published")
    api = Client()
    ids = [f["id"] for f in api.get("/api/v1/flyers").json()["results"]]
    assert flyer.pk in ids
    client.post(reverse("platform:retailer_suspend", args=[retailer.pk]))
    ids = [f["id"] for f in api.get("/api/v1/flyers").json()["results"]]
    assert flyer.pk not in ids
