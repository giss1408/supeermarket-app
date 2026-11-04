import pytest
from django.test import Client
from django.urls import reverse
from rest_framework.test import APIClient

from tests.factories import (
    PASSWORD,
    PlatformAdminFactory,
    RetailerFactory,
    StaffFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db

LIST = "platform:retailer_list"


def test_anonymous_redirected_to_login():
    resp = Client().get(reverse(LIST))
    assert resp.status_code == 302
    assert resp["Location"].startswith(reverse("platform:login"))


def test_customer_and_retailer_staff_get_403():
    for user in (UserFactory(), StaffFactory()):
        client = Client()
        client.force_login(user)
        assert client.get(reverse(LIST)).status_code == 403


def test_platform_admin_gets_200():
    client = Client()
    client.force_login(PlatformAdminFactory())
    resp = client.get(reverse(LIST))
    assert resp.status_code == 200
    assert "Commerçants" in resp.content.decode()


def test_post_without_csrf_token_is_refused():
    retailer = RetailerFactory(status="pending")
    client = Client(enforce_csrf_checks=True)
    client.force_login(PlatformAdminFactory())
    resp = client.post(reverse("platform:retailer_activate", args=[retailer.pk]))
    assert resp.status_code == 403
    retailer.refresh_from_db()
    assert retailer.status == "pending"


def test_jwt_bearer_token_does_not_authenticate_dashboard():
    admin = PlatformAdminFactory()
    token = (
        APIClient()
        .post("/api/v1/auth/login", {"email": admin.email, "password": PASSWORD}, format="json")
        .json()["access"]
    )
    resp = Client().get(reverse(LIST), HTTP_AUTHORIZATION=f"Bearer {token}")
    assert resp.status_code == 302
    assert reverse("platform:login") in resp["Location"]


def test_login_accepts_platform_admin():
    admin = PlatformAdminFactory()
    resp = Client().post(reverse("platform:login"), {"username": admin.email, "password": PASSWORD})
    assert resp.status_code == 302
    assert resp["Location"] == reverse(LIST)


@pytest.mark.parametrize("factory", [UserFactory, StaffFactory])
def test_login_rejects_non_platform_admin(factory):
    user = factory()
    client = Client()
    resp = client.post(reverse("platform:login"), {"username": user.email, "password": PASSWORD})
    assert resp.status_code == 200
    assert "réservé" in resp.content.decode()
    assert "_auth_user_id" not in client.session


def test_login_page_renders():
    assert Client().get(reverse("platform:login")).status_code == 200


def test_logout_is_post_only_and_logs_out():
    client = Client()
    client.force_login(PlatformAdminFactory())
    assert client.get(reverse("platform:logout")).status_code == 405
    resp = client.post(reverse("platform:logout"))
    assert resp.status_code == 302
    assert client.get(reverse(LIST)).status_code == 302


def test_platform_keeps_html_error_pages(settings):
    settings.DEBUG = False
    client = Client()
    client.force_login(PlatformAdminFactory())
    resp = client.get("/platform/nope/")
    assert resp.status_code == 404
    assert resp["Content-Type"].startswith("text/html")
    customer = Client()
    customer.force_login(UserFactory())
    resp = customer.get(reverse(LIST))
    assert resp.status_code == 403
    assert resp["Content-Type"].startswith("text/html")
