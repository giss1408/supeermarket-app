import pytest
from django.test import Client


def test_healthz_returns_ok(client: Client) -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_readyz_checks_the_database_and_the_cache(client: Client) -> None:
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_readyz_says_which_part_is_down_without_the_reason(client: Client, monkeypatch) -> None:
    from django.core.cache import cache

    def boom(*args, **kwargs):
        raise RuntimeError("redis password is hunter2")

    monkeypatch.setattr(cache, "set", boom)
    response = client.get("/readyz")
    assert response.status_code == 503
    assert response.json() == {"status": "unavailable", "down": ["cache"]}
    assert "hunter2" not in response.content.decode()
