import datetime

import pytest

from tests.factories import FlyerFactory, OfferFactory

pytestmark = pytest.mark.django_db

D = datetime.date


def flyer_with_offer(**kw):
    flyer = FlyerFactory(**kw)
    OfferFactory(flyer=flyer)
    return flyer


def test_publish_empty_flyer_returns_400_validation_error(staff_client):
    flyer = FlyerFactory()
    resp = staff_client.post(f"/api/v1/staff/flyers/{flyer.id}/publish")
    assert resp.status_code == 400
    body = resp.json()
    assert body["code"] == "validation_error"
    assert "at least one offer" in body["fields"]["non_field_errors"][0]
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_publish_overlapping_flyer_returns_400(staff_client):
    flyer_with_offer(status="published", valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 7))
    other = flyer_with_offer(valid_from=D(2026, 11, 7), valid_to=D(2026, 11, 14))
    resp = staff_client.post(f"/api/v1/staff/flyers/{other.id}/publish")
    assert resp.status_code == 400
    assert resp.json()["code"] == "validation_error"
    assert "overlap" in resp.json()["fields"]["non_field_errors"][0]


def test_publish_success_then_public_api_shows_it(staff_client, anon_client):
    flyer = flyer_with_offer()
    assert anon_client.get(f"/api/v1/flyers/{flyer.id}").status_code == 404
    resp = staff_client.post(f"/api/v1/staff/flyers/{flyer.id}/publish")
    assert resp.status_code == 200
    assert resp.json()["status"] == "published"
    assert len(resp.json()["offers"]) == 1
    assert anon_client.get(f"/api/v1/flyers/{flyer.id}").status_code == 200


def test_publish_idempotent(staff_client):
    flyer = flyer_with_offer()
    for _ in range(2):
        resp = staff_client.post(f"/api/v1/staff/flyers/{flyer.id}/publish")
        assert resp.status_code == 200
        assert resp.json()["status"] == "published"


def test_unpublish_hides_from_public_api(staff_client, anon_client):
    flyer = flyer_with_offer(status="published")
    assert anon_client.get(f"/api/v1/flyers/{flyer.id}").status_code == 200
    resp = staff_client.post(f"/api/v1/staff/flyers/{flyer.id}/unpublish")
    assert resp.status_code == 200
    assert resp.json()["status"] == "draft"
    assert anon_client.get(f"/api/v1/flyers/{flyer.id}").status_code == 404


def test_publish_unknown_id_404(staff_client):
    for action in ("publish", "unpublish"):
        resp = staff_client.post(f"/api/v1/staff/flyers/999999/{action}")
        assert resp.status_code == 404
        assert resp.json()["code"] == "not_found"


def test_publish_adjacent_flyers_ok(staff_client):
    a = flyer_with_offer(valid_from=D(2026, 11, 1), valid_to=D(2026, 11, 7))
    b = flyer_with_offer(valid_from=D(2026, 11, 8), valid_to=D(2026, 11, 14))
    for f in (a, b):
        assert staff_client.post(f"/api/v1/staff/flyers/{f.id}/publish").status_code == 200
