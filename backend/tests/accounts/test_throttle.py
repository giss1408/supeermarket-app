import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from tests.factories import PASSWORD, UserFactory

pytestmark = pytest.mark.django_db

LOGIN = "/api/v1/auth/login"


@pytest.fixture
def client():
    return APIClient()


def test_auth_endpoints_throttled_after_limit(client):
    user = UserFactory()
    for _ in range(10):
        r = client.post(LOGIN, {"email": user.email, "password": "wrong"}, format="json")
        assert r.status_code == 401
    r = client.post(LOGIN, {"email": user.email, "password": "wrong"}, format="json")
    assert r.status_code == 429
    body = r.json()
    assert body["code"] == "throttled"
    assert set(body) == {"code", "detail", "fields"}


@pytest.mark.parametrize(
    "path", ["/api/v1/auth/register", "/api/v1/auth/refresh", "/api/v1/auth/logout"]
)
def test_other_auth_endpoints_share_throttle(client, path):
    for _ in range(10):
        assert client.post(path, {}, format="json").status_code != 429
    assert client.post(path, {}, format="json").status_code == 429


def test_throttle_does_not_apply_to_me_endpoints(client):
    user = UserFactory()
    r = client.post(LOGIN, {"email": user.email, "password": PASSWORD}, format="json")
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {r.json()['access']}")
    for _ in range(15):
        assert client.get("/api/v1/me").status_code == 200
    assert client.get("/api/v1/me/card").status_code == 200
    cache.clear()
