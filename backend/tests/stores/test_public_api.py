import datetime
from decimal import Decimal

import pytest
from rest_framework.test import APIClient

from stores.views import StorePagination
from tests.factories import OpeningHoursFactory, StoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def client():
    return APIClient()


def make_stores():
    # Bonn centre is the query point (50.7374, 7.0982).
    near = StoreFactory(name="Near", latitude=Decimal("50.7400"), longitude=Decimal("7.1000"))
    mid = StoreFactory(
        name="Mid", latitude=Decimal("50.9375"), longitude=Decimal("6.9603")
    )  # Cologne
    far = StoreFactory(
        name="Far", latitude=Decimal("52.5200"), longitude=Decimal("13.4050")
    )  # Berlin
    return near, mid, far


def test_inactive_store_hidden_in_list_and_detail(client):
    active = StoreFactory()
    inactive = StoreFactory(is_active=False)
    resp = client.get("/api/v1/stores")
    assert [s["id"] for s in resp.data["results"]] == [active.id]
    assert client.get(f"/api/v1/stores/{inactive.id}").status_code == 404
    assert client.get(f"/api/v1/stores/{active.id}").status_code == 200


def test_stores_without_coordinates_sorted_by_name_distance_null(client):
    b = StoreFactory(name="B")
    a = StoreFactory(name="A")
    resp = client.get("/api/v1/stores")
    assert [s["id"] for s in resp.data["results"]] == [a.id, b.id]
    item = resp.data["results"][0]
    assert item["distance_km"] is None
    assert set(item) == {
        "id", "name", "address", "city", "postcode", "latitude", "longitude", "phone",
        "distance_km",
    }  # fmt: skip


def test_stores_search(client):
    hit = StoreFactory(name="Alpha", city="Bonn")
    StoreFactory(name="Beta", city="Berlin")
    assert [s["id"] for s in client.get("/api/v1/stores?q=bon").data["results"]] == [hit.id]


def test_stores_sorted_by_distance_when_coordinates_given(client):
    near, mid, far = make_stores()
    resp = client.get("/api/v1/stores?lat=50.7374&lng=7.0982")
    assert resp.status_code == 200
    results = resp.data["results"]
    assert [s["id"] for s in results] == [near.id, mid.id, far.id]
    assert results[0]["distance_km"] == pytest.approx(0.28, abs=0.05)
    assert results[1]["distance_km"] == pytest.approx(24.27, abs=0.1)
    assert results[2]["distance_km"] == pytest.approx(478.1, abs=0.5)
    assert isinstance(results[0]["distance_km"], float)


def test_stores_distance_pagination_across_pages(client, monkeypatch):
    monkeypatch.setattr(StorePagination, "page_size", 2)
    stores = [
        StoreFactory(
            name=f"S{i}", latitude=Decimal("50.0") + Decimal(i) / 10, longitude=Decimal("7.0")
        )
        for i in range(7)
    ]
    # two stores with identical distance to exercise tie handling
    stores.append(StoreFactory(name="Dup", latitude=Decimal("50.3"), longitude=Decimal("7.0")))
    url = "/api/v1/stores?lat=50.0&lng=7.0"
    seen: list[dict] = []
    pages = 0
    while url:
        resp = client.get(url)
        assert resp.status_code == 200
        seen.extend(resp.data["results"])
        url = resp.data["next"]
        pages += 1
    assert pages == 4
    ids = [s["id"] for s in seen]
    assert len(ids) == len(set(ids)) == len(stores)
    dists = [s["distance_km"] for s in seen]
    assert dists == sorted(dists)


@pytest.mark.parametrize(
    "query",
    [
        "lat=50.1",
        "lng=7.1",
        "lat=abc&lng=7",
        "lat=50&lng=xyz",
        "lat=nan&lng=7",
        "lat=inf&lng=7",
        "lat=90.1&lng=7",
        "lat=-91&lng=7",
        "lat=50&lng=180.5",
        "lat=50&lng=-181",
        "lat=&lng=7",
    ],
)
def test_stores_bad_coordinates_return_400(client, query):
    StoreFactory()
    resp = client.get(f"/api/v1/stores?{query}")
    assert resp.status_code == 400
    body = resp.json()
    assert body["code"] == "validation_error"
    assert body["fields"]


def test_stores_lat_without_lng_returns_400(client):
    resp = client.get("/api/v1/stores?lat=50.1")
    assert resp.status_code == 400
    assert "lng" in resp.json()["fields"]


def test_stores_lng_without_lat_returns_400(client):
    resp = client.get("/api/v1/stores?lng=7.1")
    assert resp.status_code == 400
    assert "lat" in resp.json()["fields"]


def test_stores_non_numeric_coordinates_return_400(client):
    resp = client.get("/api/v1/stores?lat=abc&lng=def")
    assert resp.status_code == 400
    assert set(resp.json()["fields"]) == {"lat", "lng"}


def test_stores_out_of_range_coordinates_return_400(client):
    resp = client.get("/api/v1/stores?lat=95&lng=200")
    assert resp.status_code == 400
    assert set(resp.json()["fields"]) == {"lat", "lng"}


def test_store_detail_includes_opening_hours_ordered(client):
    store = StoreFactory()
    OpeningHoursFactory(
        store=store, weekday=4, opens=datetime.time(9, 0), closes=datetime.time(18, 30)
    )
    OpeningHoursFactory(
        store=store, weekday=1, opens=datetime.time(8, 0), closes=datetime.time(20, 0)
    )
    resp = client.get(f"/api/v1/stores/{store.id}")
    assert resp.status_code == 200
    assert resp.data["opening_hours"] == [
        {"weekday": 1, "opens": "08:00", "closes": "20:00"},
        {"weekday": 4, "opens": "09:00", "closes": "18:30"},
    ]
    assert resp.data["distance_km"] is None


def test_store_without_opening_hours_returns_empty_list(client):
    store = StoreFactory()
    resp = client.get(f"/api/v1/stores/{store.id}")
    assert resp.data["opening_hours"] == []


def test_store_detail_distance_with_coordinates(client):
    near, _, _ = make_stores()
    resp = client.get(f"/api/v1/stores/{near.id}?lat=50.7374&lng=7.0982")
    assert resp.data["distance_km"] == pytest.approx(0.28, abs=0.05)
    assert client.get(f"/api/v1/stores/{near.id}?lat=50.7").status_code == 400


def test_out_of_range_latitude_row_does_not_break_distance_list(client):
    from stores.models import Store

    Store.objects.bulk_create(  # bypasses the model validators
        [
            Store(
                name="Bad",
                address="x",
                city="y",
                postcode="1",
                latitude=Decimal("91"),
                longitude=Decimal("7"),
            ),
            Store(
                name="Antipode",
                address="x",
                city="y",
                postcode="1",
                latitude=Decimal("-50.7374"),
                longitude=Decimal("-172.9018"),
            ),
        ]
    )
    StoreFactory(name="Good")
    resp = client.get("/api/v1/stores?lat=50.7374&lng=7.0982")
    assert resp.status_code == 200
    assert len(resp.json()["results"]) == 3
