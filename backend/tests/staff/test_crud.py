import datetime
from decimal import Decimal

import pytest

from catalog.models import Category, Product
from common.pagination import DefaultCursorPagination
from offers.models import Flyer, Offer
from shopping.models import ListItem
from stores.models import OpeningHours, Store
from tests.factories import (
    CategoryFactory,
    FlyerFactory,
    ListItemFactory,
    OfferFactory,
    OpeningHoursFactory,
    ProductFactory,
    StoreFactory,
)

pytestmark = pytest.mark.django_db

BASE = "/api/v1/staff"
D = datetime.date


def flyer_payload(**kw):
    return {"title": "Week 45", "valid_from": "2026-11-02", "valid_to": "2026-11-08", **kw}


def offer_payload(product, **kw):
    return {"product": product.id, "price": "1.99", **kw}


# ---------- flyers ----------


def test_staff_sees_draft_flyers(staff_client, anon_client):
    draft = FlyerFactory(status="draft")
    resp = staff_client.get(f"{BASE}/flyers")
    assert resp.status_code == 200
    assert [f["id"] for f in resp.json()["results"]] == [draft.id]
    assert staff_client.get(f"{BASE}/flyers/{draft.id}").status_code == 200
    assert anon_client.get("/api/v1/flyers").json()["results"] == []
    assert anon_client.get(f"/api/v1/flyers/{draft.id}").status_code == 404


def test_staff_creates_flyer_with_offers(staff_client):
    p1, p2 = ProductFactory(), ProductFactory()
    payload = flyer_payload(
        offers=[
            offer_payload(p1, old_price="2.49", badge_text="-20%", sort_order=2),
            offer_payload(p2, valid_from="2026-11-03", valid_to="2026-11-04"),
        ]
    )
    resp = staff_client.post(f"{BASE}/flyers", payload, format="json")
    assert resp.status_code == 201, resp.json()
    body = resp.json()
    assert body["status"] == "draft"
    assert [o["price"] for o in body["offers"]] == ["1.99", "1.99"]
    assert body["offers"][1]["old_price"] == "2.49"  # ordered by sort_order
    assert Flyer.objects.get(pk=body["id"]).offers.count() == 2


def test_create_flyer_without_offers(staff_client):
    resp = staff_client.post(f"{BASE}/flyers", flyer_payload(), format="json")
    assert resp.status_code == 201
    assert resp.json()["offers"] == []


def test_create_flyer_with_one_bad_offer_creates_nothing(staff_client):
    p = ProductFactory()
    payload = flyer_payload(offers=[offer_payload(p), offer_payload(p, price="0")])
    resp = staff_client.post(f"{BASE}/flyers", payload, format="json")
    assert resp.status_code == 400
    assert resp.json()["code"] == "validation_error"
    assert Flyer.objects.count() == 0
    assert Offer.objects.count() == 0


def test_flyer_from_after_to_rejected_via_api(staff_client):
    resp = staff_client.post(
        f"{BASE}/flyers",
        flyer_payload(valid_from="2026-11-09", valid_to="2026-11-08"),
        format="json",
    )
    assert resp.status_code == 400
    assert "valid_to" in resp.json()["fields"]
    flyer = FlyerFactory(valid_from=D(2026, 11, 2), valid_to=D(2026, 11, 8))
    resp = staff_client.patch(
        f"{BASE}/flyers/{flyer.id}", {"valid_from": "2026-11-20"}, format="json"
    )
    assert resp.status_code == 400
    assert "valid_to" in resp.json()["fields"]


def test_flyer_status_not_writable(staff_client):
    resp = staff_client.post(f"{BASE}/flyers", flyer_payload(status="published"), format="json")
    assert resp.status_code == 201
    assert resp.json()["status"] == "draft"
    flyer = FlyerFactory()
    resp = staff_client.patch(f"{BASE}/flyers/{flyer.id}", {"status": "published"}, format="json")
    assert resp.status_code == 200
    flyer.refresh_from_db()
    assert flyer.status == "draft"


def test_flyer_patch_dates_while_published_returns_400(staff_client):
    flyer = FlyerFactory(status="published")
    OfferFactory(flyer=flyer)
    for field in ("valid_from", "valid_to"):
        value = "2026-01-01" if field == "valid_from" else "2030-01-01"
        resp = staff_client.patch(f"{BASE}/flyers/{flyer.id}", {field: value}, format="json")
        assert resp.status_code == 400
        assert "unpublish" in resp.json()["fields"][field][0].lower()
    # Non-date edits and re-sending identical dates are fine.
    resp = staff_client.patch(
        f"{BASE}/flyers/{flyer.id}",
        {"title": "New", "valid_from": flyer.valid_from.isoformat()},
        format="json",
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "New"


def test_flyer_patch_rejects_offers(staff_client):
    flyer = FlyerFactory()
    resp = staff_client.patch(f"{BASE}/flyers/{flyer.id}", {"offers": []}, format="json")
    assert resp.status_code == 400
    assert "offers" in resp.json()["fields"]


def test_flyer_filter_and_delete(staff_client):
    draft = FlyerFactory(status="draft")
    pub = FlyerFactory(status="published")
    resp = staff_client.get(f"{BASE}/flyers?status=published")
    assert [f["id"] for f in resp.json()["results"]] == [pub.id]
    assert staff_client.delete(f"{BASE}/flyers/{draft.id}").status_code == 204
    assert not Flyer.objects.filter(pk=draft.id).exists()


# ---------- offers ----------


@pytest.mark.parametrize(
    ("extra", "field"),
    [
        ({"price": "0"}, "price"),
        ({"price": "-1.00"}, "price"),
        ({"price": "2.00", "old_price": "2.00"}, "old_price"),
        ({"price": "2.00", "old_price": "1.00"}, "old_price"),
        ({"valid_from": "2026-11-03"}, "valid_to"),
        ({"valid_to": "2026-11-03"}, "valid_from"),
        ({"valid_from": "2026-11-05", "valid_to": "2026-11-03"}, "valid_to"),
    ],
)
def test_offer_price_validations_return_400(staff_client, extra, field):
    flyer, product = FlyerFactory(), ProductFactory()
    payload = {"flyer": flyer.id, "product": product.id, "price": "1.50", **extra}
    resp = staff_client.post(f"{BASE}/offers", payload, format="json")
    assert resp.status_code == 400
    assert field in resp.json()["fields"]
    assert Offer.objects.count() == 0


def test_offer_patch_validates_against_stored_values(staff_client):
    offer = OfferFactory(price=Decimal("2.00"), old_price=Decimal("3.00"))
    resp = staff_client.patch(f"{BASE}/offers/{offer.id}", {"price": "3.50"}, format="json")
    assert resp.status_code == 400
    assert "old_price" in resp.json()["fields"]


def test_offer_missing_references_return_400(staff_client):
    flyer = FlyerFactory()
    for payload in (
        {"flyer": flyer.id, "product": 999999, "price": "1.00"},
        {"flyer": 999999, "product": ProductFactory().id, "price": "1.00"},
        {"flyer": flyer.id, "product": 2**62, "price": "1.00"},
    ):
        assert staff_client.post(f"{BASE}/offers", payload, format="json").status_code == 400


def test_offer_crud_and_filter(staff_client):
    f1, f2 = FlyerFactory(), FlyerFactory()
    p = ProductFactory()
    resp = staff_client.post(
        f"{BASE}/offers", {"flyer": f1.id, "product": p.id, "price": "1.50"}, format="json"
    )
    assert resp.status_code == 201
    assert resp.json()["price"] == "1.50"
    OfferFactory(flyer=f2)
    resp = staff_client.get(f"{BASE}/offers?flyer={f1.id}")
    assert len(resp.json()["results"]) == 1
    oid = resp.json()["results"][0]["id"]
    assert (
        staff_client.patch(f"{BASE}/offers/{oid}", {"badge_text": "Hot"}, format="json").json()[
            "badge_text"
        ]
        == "Hot"
    )
    assert staff_client.delete(f"{BASE}/offers/{oid}").status_code == 204


def test_remove_last_offer_of_published_flyer_returns_400(staff_client):
    pub = FlyerFactory(status="published")
    last = OfferFactory(flyer=pub)
    other = FlyerFactory()
    resp = staff_client.delete(f"{BASE}/offers/{last.id}")
    assert resp.status_code == 400
    assert "unpublish" in resp.json()["fields"]["non_field_errors"][0].lower()
    resp = staff_client.patch(f"{BASE}/offers/{last.id}", {"flyer": other.id}, format="json")
    assert resp.status_code == 400
    assert "unpublish" in resp.json()["fields"]["flyer"][0].lower()
    last.refresh_from_db()
    assert last.flyer_id == pub.id
    # With a second offer, removal and moving are allowed; drafts are unrestricted.
    second = OfferFactory(flyer=pub)
    assert staff_client.delete(f"{BASE}/offers/{second.id}").status_code == 204
    draft_offer = OfferFactory(flyer=other)
    assert staff_client.delete(f"{BASE}/offers/{draft_offer.id}").status_code == 204


def test_move_non_last_offer_of_published_flyer_ok(staff_client):
    pub = FlyerFactory(status="published")
    a, _b = OfferFactory(flyer=pub), OfferFactory(flyer=pub)
    other = FlyerFactory()
    resp = staff_client.patch(f"{BASE}/offers/{a.id}", {"flyer": other.id}, format="json")
    assert resp.status_code == 200


# ---------- products / categories ----------


def test_delete_protected_category_and_product_return_409(staff_client):
    product = ProductFactory()
    resp = staff_client.delete(f"{BASE}/categories/{product.category_id}")
    assert resp.status_code == 409
    assert resp.json()["code"] == "conflict"
    assert set(resp.json()) == {"code", "detail", "fields"}
    OfferFactory(product=product)
    resp = staff_client.delete(f"{BASE}/products/{product.id}")
    assert resp.status_code == 409
    assert resp.json()["code"] == "conflict"
    assert Product.objects.filter(pk=product.id).exists()
    assert Category.objects.filter(pk=product.category_id).exists()


def test_delete_unprotected_category_and_product(staff_client):
    category = CategoryFactory()
    assert staff_client.delete(f"{BASE}/categories/{category.id}").status_code == 204
    product = ProductFactory()
    ListItemFactory(product=product)
    assert staff_client.delete(f"{BASE}/products/{product.id}").status_code == 204
    assert ListItem.objects.count() == 0


def test_category_duplicate_slug_returns_400(staff_client):
    CategoryFactory(slug="dairy")
    resp = staff_client.post(
        f"{BASE}/categories", {"name": "Dairy 2", "slug": "dairy"}, format="json"
    )
    assert resp.status_code == 400
    assert "slug" in resp.json()["fields"]
    resp = staff_client.post(
        f"{BASE}/categories", {"name": "Fruit", "slug": "fruit", "sort_order": 3}, format="json"
    )
    assert resp.status_code == 201
    assert resp.json() == {
        "id": resp.json()["id"],
        "name": "Fruit",
        "slug": "fruit",
        "sort_order": 3,
    }


def test_product_crud_and_filters(staff_client):
    cat, cat2 = CategoryFactory(), CategoryFactory()
    resp = staff_client.post(
        f"{BASE}/products",
        {"name": "Milk", "category": cat.id, "unit": "1 L", "ean": "12345678"},
        format="json",
    )
    assert resp.status_code == 201
    assert resp.json()["image"] is None
    assert resp.json()["category"] == cat.id
    ProductFactory(name="Bread", category=cat2)
    assert len(staff_client.get(f"{BASE}/products?q=mil").json()["results"]) == 1
    assert len(staff_client.get(f"{BASE}/products?category={cat2.id}").json()["results"]) == 1


def test_product_image_is_read_only_absolute_url(staff_client):
    product = ProductFactory(image="products/x.jpg")
    resp = staff_client.get(f"{BASE}/products/{product.id}")
    assert resp.json()["image"].startswith("http://testserver/")
    resp = staff_client.patch(f"{BASE}/products/{product.id}", {"image": "evil"}, format="json")
    assert resp.status_code == 200
    product.refresh_from_db()
    assert product.image.name == "products/x.jpg"


def test_product_ean_validation_returns_400(staff_client):
    cat = CategoryFactory()
    resp = staff_client.post(
        f"{BASE}/products", {"name": "X", "category": cat.id, "ean": "123"}, format="json"
    )
    assert resp.status_code == 400
    assert "ean" in resp.json()["fields"]
    ProductFactory(ean="4006381333931")
    resp = staff_client.post(
        f"{BASE}/products", {"name": "Y", "category": cat.id, "ean": "4006381333931"}, format="json"
    )
    assert resp.status_code == 400
    assert "ean" in resp.json()["fields"]
    resp = staff_client.post(f"{BASE}/products", {"name": "Z", "category": 999999}, format="json")
    assert resp.status_code == 400
    assert "category" in resp.json()["fields"]


# ---------- stores ----------


def store_payload(**kw):
    return {
        "name": "Main",
        "address": "1 High St",
        "city": "Bonn",
        "postcode": "53111",
        "latitude": "50.7374",
        "longitude": "7.0982",
        **kw,
    }


def test_store_create_with_hours(staff_client):
    hours = [
        {"weekday": 0, "opens": "08:00", "closes": "20:00"},
        {"weekday": 5, "opens": "09:00", "closes": "14:30"},
    ]
    resp = staff_client.post(f"{BASE}/stores", store_payload(opening_hours=hours), format="json")
    assert resp.status_code == 201, resp.json()
    body = resp.json()
    assert body["is_active"] is True
    assert body["opening_hours"] == hours
    assert body["latitude"] == "50.737400"


def test_store_create_validation(staff_client):
    for extra in ({"latitude": "91"}, {"longitude": "-181"}):
        resp = staff_client.post(f"{BASE}/stores", store_payload(**extra), format="json")
        assert resp.status_code == 400
    assert Store.objects.count() == 0


def test_staff_updates_store_opening_hours(staff_client):
    store = StoreFactory()
    OpeningHoursFactory(store=store, weekday=0)
    OpeningHoursFactory(store=store, weekday=1)
    url = f"{BASE}/stores/{store.id}"

    # omit = unchanged
    resp = staff_client.patch(url, {"city": "Köln"}, format="json")
    assert resp.status_code == 200
    assert [h["weekday"] for h in resp.json()["opening_hours"]] == [0, 1]
    assert store.opening_hours.count() == 2

    # provided = replaced
    new = [{"weekday": 3, "opens": "10:00", "closes": "18:00"}]
    resp = staff_client.patch(url, {"opening_hours": new}, format="json")
    assert resp.status_code == 200
    assert resp.json()["opening_hours"] == new
    assert list(store.opening_hours.values_list("weekday", flat=True)) == [3]
    assert staff_client.get(url).json()["opening_hours"] == new

    # empty list clears
    resp = staff_client.patch(url, {"opening_hours": []}, format="json")
    assert resp.status_code == 200
    assert store.opening_hours.count() == 0


@pytest.mark.parametrize(
    "hours",
    [
        [{"weekday": 1, "opens": "08:00", "closes": "12:00"}] * 2,
        [{"weekday": 1, "opens": "12:00", "closes": "12:00"}],
        [{"weekday": 1, "opens": "13:00", "closes": "12:00"}],
        [{"weekday": 7, "opens": "08:00", "closes": "12:00"}],
        [{"weekday": -1, "opens": "08:00", "closes": "12:00"}],
        [{"weekday": 1, "opens": "bad", "closes": "12:00"}],
    ],
)
def test_invalid_opening_hours_return_400_and_change_nothing(staff_client, hours):
    store = StoreFactory()
    OpeningHoursFactory(store=store, weekday=0)
    resp = staff_client.patch(f"{BASE}/stores/{store.id}", {"opening_hours": hours}, format="json")
    assert resp.status_code == 400
    assert "opening_hours" in resp.json()["fields"]
    assert list(OpeningHours.objects.filter(store=store).values_list("weekday", flat=True)) == [0]


def test_store_filters_and_inactive_visible(staff_client):
    active = StoreFactory(name="Alpha")
    inactive = StoreFactory(name="Beta", is_active=False)
    ids = [s["id"] for s in staff_client.get(f"{BASE}/stores").json()["results"]]
    assert ids == [active.id, inactive.id]
    res = staff_client.get(f"{BASE}/stores?is_active=false").json()["results"]
    assert [s["id"] for s in res] == [inactive.id]
    res = staff_client.get(f"{BASE}/stores?q=alp").json()["results"]
    assert [s["id"] for s in res] == [active.id]


# ---------- cross-cutting ----------


@pytest.mark.parametrize(
    "query",
    [
        "flyers?status=bogus",
        "offers?flyer=abc",
        "offers?flyer=99999999999999999999",
        "products?category=abc",
        "stores?is_active=maybe",
    ],
)
def test_invalid_filter_returns_400(staff_client, query):
    resp = staff_client.get(f"{BASE}/{query}")
    assert resp.status_code == 400
    assert resp.json()["code"] == "validation_error"


@pytest.mark.parametrize("resource", ["flyers", "offers", "products", "categories", "stores"])
def test_put_not_allowed(staff_client, resource):
    resp = staff_client.put(f"{BASE}/{resource}/1", {}, format="json")
    assert resp.status_code == 405
    assert resp.json()["code"] == "method_not_allowed"


def test_pagination_walks_all_pages(staff_client, monkeypatch):
    monkeypatch.setattr(DefaultCursorPagination, "page_size", 2)
    made = [FlyerFactory(valid_from=D(2026, 1, 1) + datetime.timedelta(days=i)) for i in range(5)]
    seen: list[int] = []
    url: str | None = f"{BASE}/flyers"
    while url:
        body = staff_client.get(url).json()
        seen += [f["id"] for f in body["results"]]
        url = body["next"]
    assert seen == [f.id for f in reversed(made)]


def test_flyers_list_query_count(staff_client, django_assert_max_num_queries):
    for _ in range(5):
        OfferFactory(flyer=FlyerFactory())
    with django_assert_max_num_queries(4):
        resp = staff_client.get(f"{BASE}/flyers")
    assert resp.status_code == 200
    assert len(resp.json()["results"]) == 5


def test_flyer_detail_with_offers_query_count(staff_client, django_assert_max_num_queries):
    flyer = FlyerFactory()
    for _ in range(6):
        OfferFactory(flyer=flyer)
    with django_assert_max_num_queries(4):
        resp = staff_client.get(f"{BASE}/flyers/{flyer.id}")
    assert resp.status_code == 200
    assert len(resp.json()["offers"]) == 6
