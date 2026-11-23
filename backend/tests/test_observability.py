"""Platform monitoring: /metrics is private and carries no personal data; requests get an id; logs
mask numbers and tokens."""

import logging

import pytest
from django.test import Client

pytest.importorskip("regisse_kit.django_observability")

OBS = "regisse_kit.django_observability.ObservabilityMiddleware"
TOKEN = "t" * 40


@pytest.fixture
def obs(settings):
    settings.MIDDLEWARE = [OBS, *settings.MIDDLEWARE]
    settings.OBSERVABILITY_SERVICE = "supermarket"
    settings.METRICS_TOKEN = TOKEN


def test_metrics_answer_404_when_no_token_is_configured(client: Client, settings) -> None:
    settings.METRICS_TOKEN = ""
    assert client.get("/metrics").status_code == 404


def test_metrics_need_the_bearer_token(client: Client, obs) -> None:
    assert client.get("/metrics").status_code == 401
    assert client.get("/metrics", HTTP_AUTHORIZATION="Bearer nope").status_code == 401
    assert client.get("/metrics", HTTP_AUTHORIZATION=f"Bearer {TOKEN}").status_code == 200


def test_requests_are_counted_by_route_without_query_strings(client: Client, obs, caplog) -> None:
    caplog.set_level(logging.INFO)
    client.get("/healthz?phone=0701020304", HTTP_X_REQUEST_ID="req-super-1")
    client.get("/definitely-not-a-route/0701020304")
    body = client.get("/metrics", HTTP_AUTHORIZATION=f"Bearer {TOKEN}").content.decode()
    assert 'service="supermarket"' in body and 'route="unmatched"' in body
    assert "0701020304" not in body
    logged = " ".join(
        str(v) for r in caplog.records if r.name == "supermarket.http" for v in r.__dict__.values()
    )
    assert "0701020304" not in logged


def test_a_request_id_is_echoed(client: Client, obs) -> None:
    assert client.get("/healthz", HTTP_X_REQUEST_ID="abc-12345")["X-Request-ID"] == "abc-12345"
