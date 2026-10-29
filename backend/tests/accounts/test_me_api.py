import pytest
from rest_framework.test import APIClient

from accounts.models import LoyaltyCard, User
from tests.factories import PASSWORD, StaffFactory, UserFactory

pytestmark = pytest.mark.django_db

ME = "/api/v1/me"
CARD = "/api/v1/me/card"
LOGIN = "/api/v1/auth/login"
REFRESH = "/api/v1/auth/refresh"


@pytest.fixture
def client():
    return APIClient()


def _login(client, user):
    r = client.post(LOGIN, {"email": user.email, "password": PASSWORD}, format="json")
    assert r.status_code == 200
    return r.json()


def _auth(client, user):
    tokens = _login(client, user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return tokens


def test_get_me_requires_auth(client):
    r = client.get(ME)
    assert r.status_code == 401
    assert r.json()["code"] == "not_authenticated"
    assert set(r.json()) == {"code", "detail", "fields"}


def test_get_me_returns_profile(client):
    user = UserFactory()
    _auth(client, user)
    r = client.get(ME)
    assert r.status_code == 200
    assert r.json() == {"id": user.id, "email": user.email, "name": user.name, "role": "customer"}


def test_patch_me_updates_name(client):
    user = UserFactory()
    _auth(client, user)
    r = client.patch(ME, {"name": "New Name"}, format="json")
    assert r.status_code == 200
    assert r.json()["name"] == "New Name"
    user.refresh_from_db()
    assert user.name == "New Name"


def test_patch_me_cannot_change_role(client):
    user = UserFactory()
    _auth(client, user)
    r = client.patch(ME, {"role": "staff", "email": "evil@x.com"}, format="json")
    assert r.status_code == 200
    assert r.json()["role"] == "customer"
    user.refresh_from_db()
    assert user.role == "customer"
    assert user.email != "evil@x.com"


def test_get_me_card_returns_number(client):
    user = UserFactory()
    _auth(client, user)
    r = client.get(CARD)
    assert r.status_code == 200
    number = user.card.number
    assert len(number) == 13
    assert r.json() == {"number": number, "barcode_value": number}


def test_staff_has_no_card_returns_404(client):
    _auth(client, StaffFactory())
    r = client.get(CARD)
    assert r.status_code == 404
    assert r.json()["code"] == "not_found"
    assert set(r.json()) == {"code", "detail", "fields"}


def test_card_requires_auth(client):
    assert client.get(CARD).status_code == 401


def test_delete_me_requires_auth(client):
    r = client.delete(ME)
    assert r.status_code == 401
    assert r.json()["code"] == "not_authenticated"


def test_delete_me_removes_user_and_card(client):
    user = UserFactory()
    _auth(client, user)
    r = client.delete(ME)
    assert r.status_code == 204
    assert not User.objects.filter(pk=user.pk).exists()
    assert not LoyaltyCard.objects.filter(user_id=user.pk).exists()


def test_delete_me_invalidates_tokens(client):
    user = UserFactory()
    tokens = _auth(client, user)
    # a blacklisted token row must cascade too
    other = _login(client, user)
    client.post("/api/v1/auth/logout", {"refresh": other["refresh"]}, format="json")
    assert client.delete(ME).status_code == 204

    assert client.get(ME).status_code == 401
    fresh = APIClient()
    r = fresh.post(REFRESH, {"refresh": tokens["refresh"]}, format="json")
    assert r.status_code == 401
