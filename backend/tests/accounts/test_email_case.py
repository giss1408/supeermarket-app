import pytest
from rest_framework.test import APIClient

from accounts.models import User
from tests.factories import PASSWORD

pytestmark = pytest.mark.django_db

REGISTER = "/api/v1/auth/register"
LOGIN = "/api/v1/auth/login"


@pytest.fixture
def client():
    return APIClient()


def _register(client, email="Ann@X.com"):
    return client.post(
        REGISTER, {"email": email, "password": PASSWORD, "name": "Ann"}, format="json"
    )


def _login(client, email, password=PASSWORD):
    return client.post(LOGIN, {"email": email, "password": password}, format="json")


def test_register_stores_lowercase_and_login_is_case_insensitive(client):
    assert _register(client).status_code == 201
    assert User.objects.get().email == "ann@x.com"
    for variant in ("ann@x.com", "ANN@X.COM", "Ann@X.com"):
        assert _login(client, variant).status_code == 200


def test_login_trims_surrounding_whitespace(client):
    _register(client)
    assert _login(client, "  ann@x.com  ").status_code == 200


def test_wrong_password_still_401(client):
    _register(client)
    assert _login(client, "ANN@X.COM", "wrong-password").status_code == 401


def test_create_user_lowercases_whole_email():
    user = User.objects.create_user("Mixed@Case.COM", PASSWORD)
    assert User.objects.get(pk=user.pk).email == "mixed@case.com"
    admin = User.objects.create_superuser("Boss@Case.COM", PASSWORD)
    assert admin.email == "boss@case.com"


def test_legacy_mixed_case_row_can_still_log_in(client):
    user = User.objects.create_user("legacy@x.com", PASSWORD)
    User.objects.filter(pk=user.pk).update(email="Legacy@X.com")
    assert _login(client, "legacy@x.com").status_code == 200


@pytest.mark.parametrize("dup", ["ann@x.com", "ANN@X.COM", "Ann@X.com"])
def test_register_duplicate_any_casing_is_400(client, dup):
    assert _register(client).status_code == 201
    resp = _register(client, dup)
    assert resp.status_code == 400
    assert "email" in resp.json()["fields"]
