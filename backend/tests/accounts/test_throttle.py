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


def _post(client, xff=None):
    extra = {"HTTP_X_FORWARDED_FOR": xff} if xff else {}
    return client.post(LOGIN, {"email": "n@x.com", "password": "wrong"}, format="json", **extra)


def _num_proxies(settings, value):
    settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "NUM_PROXIES": value}


def test_default_num_proxies_is_zero_in_base_settings(settings):
    assert settings.REST_FRAMEWORK["NUM_PROXIES"] == 0


def test_one_proxy_gives_each_client_ip_its_own_bucket(client, settings):
    _num_proxies(settings, 1)
    for _ in range(10):
        assert _post(client, "198.51.100.1").status_code == 401
    assert _post(client, "198.51.100.1").status_code == 429
    assert _post(client, "198.51.100.2").status_code == 401


def test_one_proxy_keys_on_rightmost_xff_entry_ignoring_spoofed_prefix(client, settings):
    _num_proxies(settings, 1)
    for i in range(10):
        assert _post(client, f"10.0.0.{i}, 198.51.100.1").status_code == 401
    assert _post(client, "1.2.3.4, 198.51.100.1").status_code == 429
    assert _post(client, "1.2.3.4, 198.51.100.2").status_code == 401


def test_zero_proxies_ignores_xff(client, settings):
    _num_proxies(settings, 0)
    for i in range(10):
        assert _post(client, f"198.51.100.{i}").status_code == 401
    assert _post(client, "198.51.100.200").status_code == 429
