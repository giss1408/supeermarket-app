import re

import pytest
from rest_framework.test import APIClient

from accounts.models import LoyaltyCard, User
from tests.factories import PASSWORD, UserFactory

pytestmark = pytest.mark.django_db

REGISTER = "/api/v1/auth/register"
LOGIN = "/api/v1/auth/login"
REFRESH = "/api/v1/auth/refresh"
LOGOUT = "/api/v1/auth/logout"


@pytest.fixture
def client():
    return APIClient()


def _register(client, **over):
    data = {"email": "a@x.com", "password": PASSWORD, "name": "Ann"} | over
    return client.post(REGISTER, data, format="json")


def _login(client, user):
    r = client.post(LOGIN, {"email": user.email, "password": PASSWORD}, format="json")
    assert r.status_code == 200
    return r.json()


def test_register_creates_customer_and_card(client):
    r = _register(client)
    assert r.status_code == 201
    body = r.json()
    assert set(body) == {"id", "email", "name", "role"}
    assert body["role"] == "customer"
    user = User.objects.get(pk=body["id"])
    assert re.fullmatch(r"\d{13}", LoyaltyCard.objects.get(user=user).number)


def test_register_duplicate_email_case_insensitive_returns_400_field_error(client):
    assert _register(client).status_code == 201
    r = _register(client, email="A@x.com")
    assert r.status_code == 400
    assert "email" in r.json()["fields"]
    assert r.json()["code"] == "validation_error"


def test_register_ignores_role_field(client):
    r = _register(client, role="staff")
    assert r.status_code == 201
    assert r.json()["role"] == "customer"
    assert User.objects.get(email="a@x.com").role == "customer"


def test_register_weak_password_returns_400_field_error(client):
    r = _register(client, password="123")
    assert r.status_code == 400
    assert "password" in r.json()["fields"]


def test_register_integrity_error_race_returns_400(client, monkeypatch):
    from accounts import serializers

    monkeypatch.setattr(serializers, "_email_taken", lambda email: False)
    UserFactory(email="a@x.com")
    r = _register(client, email="A@x.com")
    assert r.status_code == 400
    assert "email" in r.json()["fields"]


def test_login_returns_access_and_refresh(client):
    tokens = _login(client, UserFactory())
    assert set(tokens) == {"access", "refresh"}


def test_login_wrong_password_returns_401_standard_error_shape(client):
    user = UserFactory()
    r = client.post(LOGIN, {"email": user.email, "password": "nope"}, format="json")
    assert r.status_code == 401
    body = r.json()
    assert set(body) == {"code", "detail", "fields"}


def test_invalid_access_token_standard_error_shape(client):
    client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
    r = client.post(LOGOUT, {"refresh": "x"}, format="json")
    assert r.status_code == 401
    assert set(r.json()) == {"code", "detail", "fields"}


def test_refresh_rotates_and_old_token_rejected(client):
    tokens = _login(client, UserFactory())
    r = client.post(REFRESH, {"refresh": tokens["refresh"]}, format="json")
    assert r.status_code == 200
    assert r.json()["refresh"] != tokens["refresh"]
    again = client.post(REFRESH, {"refresh": tokens["refresh"]}, format="json")
    assert again.status_code == 401
    assert set(again.json()) == {"code", "detail", "fields"}


def test_logout_blacklists_refresh(client):
    tokens = _login(client, UserFactory())
    r = client.post(LOGOUT, {"refresh": tokens["refresh"]}, format="json")
    assert r.status_code == 204
    after = client.post(REFRESH, {"refresh": tokens["refresh"]}, format="json")
    assert after.status_code == 401


@pytest.mark.parametrize("payload", [{}, {"refresh": "garbage"}])
def test_logout_invalid_or_missing_token_returns_400(client, payload):
    r = client.post(LOGOUT, payload, format="json")
    assert r.status_code == 400
    assert set(r.json()) == {"code", "detail", "fields"}
