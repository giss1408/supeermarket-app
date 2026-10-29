import datetime

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from tests.factories import CategoryFactory, FlyerFactory, OfferFactory, ProductFactory

pytestmark = pytest.mark.django_db

TODAY = datetime.date(2026, 10, 29)


def day(n: int) -> datetime.date:
    return TODAY + datetime.timedelta(days=n)


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def today(monkeypatch):
    monkeypatch.setattr(timezone, "localdate", lambda *a, **k: TODAY)
    return TODAY


def published(**kw):
    return FlyerFactory(status="published", **kw)


def test_draft_flyer_invisible_to_anonymous_list_and_detail(client):
    draft = FlyerFactory(status="draft")
    pub = published(valid_from=day(20), valid_to=day(26))
    resp = client.get("/api/v1/flyers")
    assert resp.status_code == 200
    assert [f["id"] for f in resp.data["results"]] == [pub.id]
    assert client.get(f"/api/v1/flyers/{draft.id}").status_code == 404
    detail = client.get(f"/api/v1/flyers/{pub.id}")
    assert detail.status_code == 200
    assert detail.data["offers"] == []


def test_flyer_list_fields_and_order(client):
    old = published(valid_from=day(-30), valid_to=day(-24))
    new = published(valid_from=day(-10), valid_to=day(-4))
    OfferFactory(flyer=new)
    resp = client.get("/api/v1/flyers")
    assert [f["id"] for f in resp.data["results"]] == [new.id, old.id]
    first = resp.data["results"][0]
    assert set(first) == {"id", "title", "valid_from", "valid_to", "cover_image", "offer_count"}
    assert first["offer_count"] == 1
    assert first["cover_image"] is None


def test_current_flyer_is_published_one_covering_today(client, today):
    published(valid_from=day(-30), valid_to=day(-24))
    current = published(valid_from=day(-2), valid_to=day(4))
    published(valid_from=day(10), valid_to=day(16))
    FlyerFactory(status="draft", valid_from=day(-2), valid_to=day(4))
    resp = client.get("/api/v1/flyers/current")
    assert resp.status_code == 200
    assert resp.data["id"] == current.id


def test_current_flyer_404_when_none(client, today):
    FlyerFactory(status="draft", valid_from=day(-1), valid_to=day(3))
    resp = client.get("/api/v1/flyers/current")
    assert resp.status_code == 404
    assert resp.json()["code"] == "not_found"
    assert set(resp.json()) == {"code", "detail", "fields"}


def test_current_flyer_includes_offers_in_order(client, today):
    flyer = published(valid_from=day(-1), valid_to=day(5))
    o3 = OfferFactory(flyer=flyer, sort_order=2)
    o1 = OfferFactory(flyer=flyer, sort_order=1)
    o2 = OfferFactory(flyer=flyer, sort_order=1)
    resp = client.get("/api/v1/flyers/current")
    assert [o["id"] for o in resp.data["offers"]] == [o1.id, o2.id, o3.id]
    offer = resp.data["offers"][0]
    assert offer["price"] == "1.99"
    assert offer["old_price"] is None
    assert offer["product"]["image"] is None
    assert set(offer["product"]["category"]) == {"id", "name", "slug"}


def test_offers_filter_by_category_slug_and_search(client):
    flyer = published()
    fruit = CategoryFactory(slug="fruit")
    dairy = CategoryFactory(slug="dairy")
    apple = OfferFactory(flyer=flyer, product=ProductFactory(name="Red Apple", category=fruit))
    OfferFactory(flyer=flyer, product=ProductFactory(name="Milk", category=dairy))
    badge = OfferFactory(
        flyer=flyer, product=ProductFactory(name="Pear", category=fruit), badge_text="APPLE deal"
    )
    ids = lambda r: [o["id"] for o in r.data["results"]]  # noqa: E731
    assert len(ids(client.get("/api/v1/offers"))) == 3
    assert ids(client.get("/api/v1/offers?category=fruit")) == [apple.id, badge.id]
    assert ids(client.get("/api/v1/offers?q=apple")) == [apple.id, badge.id]
    assert ids(client.get("/api/v1/offers?category=fruit&q=pear")) == [badge.id]
    assert ids(client.get(f"/api/v1/offers?flyer={flyer.id}")) != []
    assert ids(client.get(f"/api/v1/offers?flyer={flyer.id + 999}")) == []
    first = client.get("/api/v1/offers").data["results"][0]
    assert set(first) == {
        "id", "flyer", "price", "old_price", "badge_text", "valid_from", "valid_to", "product",
    }  # fmt: skip
    assert set(first["product"]) == {
        "id", "name", "description", "image", "unit", "category",
    }  # fmt: skip


def test_offers_exclude_draft_flyers(client):
    OfferFactory(flyer=FlyerFactory(status="draft"))
    shown = OfferFactory(flyer=published(valid_from=day(40), valid_to=day(45)))
    resp = client.get("/api/v1/offers")
    assert [o["id"] for o in resp.data["results"]] == [shown.id]


def test_unknown_category_slug_returns_empty_page(client):
    OfferFactory(flyer=published())
    resp = client.get("/api/v1/offers?category=nope")
    assert resp.status_code == 200
    assert resp.data["results"] == []


def test_empty_tables_return_empty_pages(client):
    for url in ("/api/v1/flyers", "/api/v1/offers", "/api/v1/categories", "/api/v1/stores"):
        resp = client.get(url)
        assert resp.status_code == 200, url
        assert resp.data["results"] == []


@pytest.mark.parametrize(
    "url",
    [
        "/api/v1/flyers",
        "/api/v1/flyers/current",
        "/api/v1/flyers/1",
        "/api/v1/offers",
        "/api/v1/categories",
        "/api/v1/stores",
        "/api/v1/stores/1",
    ],
)
def test_public_endpoints_ignore_bad_bearer_token(client, url):
    resp = client.get(url, HTTP_AUTHORIZATION="Bearer garbage.token.value")
    assert resp.status_code in (200, 404)
    assert resp.status_code != 401


def test_bad_bearer_token_on_populated_list(client):
    OfferFactory(flyer=published())
    resp = client.get("/api/v1/offers", HTTP_AUTHORIZATION="Bearer garbage")
    assert resp.status_code == 200


@pytest.mark.parametrize("method", ["post", "put", "patch", "delete"])
@pytest.mark.parametrize(
    "url",
    [
        "/api/v1/flyers",
        "/api/v1/flyers/current",
        "/api/v1/flyers/1",
        "/api/v1/offers",
        "/api/v1/categories",
        "/api/v1/stores",
        "/api/v1/stores/1",
    ],
)
def test_write_methods_not_allowed(client, method, url):
    resp = getattr(client, method)(url, {}, format="json")
    assert resp.status_code == 405
    body = resp.json()
    assert set(body) == {"code", "detail", "fields"}
    assert body["code"] == "method_not_allowed"


def test_current_flyer_query_count(client, today, django_assert_max_num_queries):
    flyer = published(valid_from=day(-1), valid_to=day(5))
    for i in range(10):
        OfferFactory(flyer=flyer, sort_order=i)
    with django_assert_max_num_queries(3):
        resp = client.get("/api/v1/flyers/current")
    assert len(resp.data["offers"]) == 10


def test_offers_list_query_count(client, django_assert_max_num_queries):
    flyer = published()
    for i in range(10):
        OfferFactory(flyer=flyer, sort_order=i)
    with django_assert_max_num_queries(3):
        resp = client.get("/api/v1/offers")
    assert len(resp.data["results"]) == 10
