import re
from datetime import timedelta

import pytest
from django.test import override_settings
from django.urls import path
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.test import APIClient
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import AccessToken

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


class _Protected(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({})


urlpatterns = [path("protected", _Protected.as_view())]


@override_settings(ROOT_URLCONF=__name__)
def test_invalid_access_token_standard_error_shape(client):
    client.credentials(HTTP_AUTHORIZATION="Bearer garbage")
    r = client.get("/protected")
    assert r.status_code == 401
    assert set(r.json()) == {"code", "detail", "fields"}


@pytest.mark.parametrize("bearer", ["garbage", "expired"])
def test_logout_works_with_bad_access_token(client, bearer):
    user = UserFactory()
    tokens = _login(client, user)
    if bearer == "expired":
        token = AccessToken(tokens["access"])
        token.set_exp(lifetime=-timedelta(minutes=1))
        bearer = str(token)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {bearer}")
    r = client.post(LOGOUT, {"refresh": tokens["refresh"]}, format="json")
    assert r.status_code == 204
    client.credentials()
    assert client.post(REFRESH, {"refresh": tokens["refresh"]}, format="json").status_code == 401


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
