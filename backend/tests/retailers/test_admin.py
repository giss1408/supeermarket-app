import pytest
from django.contrib import admin
from django.test import Client
from django.urls import reverse

from retailers.models import Retailer, RetailerChange, Subscription
from tests.factories import RetailerFactory, UserFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def su_client():
    su = UserFactory(is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(su)
    return client


def test_retailer_admin_status_is_read_only():
    assert "status" in admin.site._registry[Retailer].readonly_fields


def test_status_cannot_be_changed_via_admin_form(su_client):
    retailer = RetailerFactory(status=Retailer.Status.ACTIVE)
    url = reverse("admin:retailers_retailer_change", args=[retailer.pk])
    resp = su_client.post(
        url, {"name": retailer.name, "slug": retailer.slug, "status": Retailer.Status.SUSPENDED}
    )
    assert resp.status_code == 302
    retailer.refresh_from_db()
    assert retailer.status == Retailer.Status.ACTIVE
    assert not RetailerChange.objects.filter(retailer=retailer).exists()


def test_admin_create_leaves_status_pending(su_client):
    resp = su_client.post(
        reverse("admin:retailers_retailer_add"), {"name": "New Co", "slug": "new-co"}
    )
    assert resp.status_code == 302
    assert Retailer.objects.get(slug="new-co").status == Retailer.Status.PENDING


def test_subscription_admin_is_view_only(rf):
    su = UserFactory(is_staff=True, is_superuser=True)
    request = rf.get("/")
    request.user = su
    model_admin = admin.site._registry[Subscription]
    assert not model_admin.has_add_permission(request)
    assert not model_admin.has_change_permission(request)
    assert not model_admin.has_delete_permission(request)
