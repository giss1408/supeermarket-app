import pytest
from rest_framework.test import APIClient

from tests.factories import (
    CategoryFactory,
    FlyerFactory,
    OfferFactory,
    PaymentMethodFactory,
    PlatformAdminFactory,
    ProductFactory,
    RetailerFactory,
    StaffFactory,
    StoreFactory,
    default_retailer,
)

pytestmark = pytest.mark.django_db

BASE = "/api/v1/staff"


def _offer(retailer):
    return OfferFactory(
        flyer=FlyerFactory(retailer=retailer), product=ProductFactory(retailer=retailer)
    )


# resource -> (route, factory(retailer) -> row, patch body)
RESOURCES = {
    "flyers": ("flyers", lambda r: FlyerFactory(retailer=r), {"title": "Hacked"}),
    "offers": ("offers", _offer, {"price": "9.99"}),
    "products": ("products", lambda r: ProductFactory(retailer=r), {"name": "Hacked"}),
    "categories": ("categories", lambda r: CategoryFactory(retailer=r), {"name": "Hacked"}),
    "stores": ("stores", lambda r: StoreFactory(retailer=r), {"name": "Hacked"}),
    "payment-methods": (
        "payment-methods",
        lambda r: PaymentMethodFactory(retailer=r),
        {"display_name": "Hacked", "current_password": "x"},
    ),
}
param = pytest.mark.parametrize("name", list(RESOURCES))


@pytest.fixture
def other():
    return RetailerFactory()


@pytest.fixture
def mine():
    return default_retailer()


@param
def test_list_excludes_other_retailers_rows(staff_client, mine, other, name):
    route, make, _ = RESOURCES[name]
    own, foreign = make(mine), make(other)
    resp = staff_client.get(f"{BASE}/{route}")
    assert resp.status_code == 200
    ids = [r["id"] for r in resp.json()["results"]]
    assert own.pk in ids
    assert foreign.pk not in ids


@param
def test_retrieve_patch_delete_other_retailers_row_returns_404(staff_client, other, name):
    route, make, body = RESOURCES[name]
    foreign = make(other)
    url = f"{BASE}/{route}/{foreign.pk}"
    assert staff_client.get(url).status_code == 404
    assert staff_client.patch(url, body, format="json").status_code == 404
    if name != "payment-methods":  # payment methods are never deleted (405)
        assert staff_client.delete(url).status_code == 404
    assert type(foreign).objects.filter(pk=foreign.pk).exists()


def test_created_rows_get_callers_retailer(staff_client, mine):
    category = CategoryFactory(retailer=mine)
    product = ProductFactory(retailer=mine)
    flyer = staff_client.post(
        f"{BASE}/flyers",
        {
            "title": "W",
            "valid_from": "2026-11-02",
            "valid_to": "2026-11-08",
            "offers": [{"product": product.id, "price": "1.00"}],
        },
        format="json",
    )
    assert flyer.status_code == 201, flyer.json()
    from offers.models import Flyer

    assert Flyer.objects.get(pk=flyer.json()["id"]).retailer == mine
    for route, body in {
        "categories": {"name": "C", "slug": "c-new"},
        "products": {"name": "P", "category": category.id, "unit": "1 kg"},
        "stores": {
            "name": "S",
            "address": "a",
            "city": "c",
            "postcode": "1",
            "latitude": "1.0",
            "longitude": "1.0",
        },
    }.items():
        resp = staff_client.post(f"{BASE}/{route}", body, format="json")
        assert resp.status_code == 201, resp.json()
        from django.apps import apps

        model = {"categories": "catalog.Category", "products": "catalog.Product"}.get(
            route, "stores.Store"
        )
        assert apps.get_model(model).objects.get(pk=resp.json()["id"]).retailer == mine


def test_offer_created_via_flyers_nested_with_foreign_product_is_400(staff_client, other):
    foreign_product = ProductFactory(retailer=other)
    resp = staff_client.post(
        f"{BASE}/flyers",
        {
            "title": "W",
            "valid_from": "2026-11-02",
            "valid_to": "2026-11-08",
            "offers": [{"product": foreign_product.id, "price": "1.00"}],
        },
        format="json",
    )
    assert resp.status_code == 400


def test_offer_with_foreign_flyer_is_400(staff_client, mine, other):
    foreign_flyer = FlyerFactory(retailer=other, title="SECRET-TITLE")
    resp = staff_client.post(
        f"{BASE}/offers",
        {"flyer": foreign_flyer.id, "product": ProductFactory(retailer=mine).id, "price": "1.00"},
        format="json",
    )
    assert resp.status_code == 400
    assert "flyer" in resp.json()["fields"]
    assert "SECRET-TITLE" not in resp.content.decode()


def test_offer_with_foreign_product_is_400(staff_client, mine, other):
    foreign_product = ProductFactory(retailer=other, name="SECRET-NAME")
    resp = staff_client.post(
        f"{BASE}/offers",
        {"flyer": FlyerFactory(retailer=mine).id, "product": foreign_product.id, "price": "1.00"},
        format="json",
    )
    assert resp.status_code == 400
    assert "product" in resp.json()["fields"]
    assert "SECRET-NAME" not in resp.content.decode()


def test_offer_patch_with_foreign_product_or_flyer_is_400(staff_client, mine, other):
    offer = _offer(mine)
    url = f"{BASE}/offers/{offer.pk}"
    assert (
        staff_client.patch(url, {"product": ProductFactory(retailer=other).id}, format="json")
    ).status_code == 400
    assert (
        staff_client.patch(url, {"flyer": FlyerFactory(retailer=other).id}, format="json")
    ).status_code == 400
    offer.refresh_from_db()
    assert offer.flyer.retailer == mine


def test_product_with_foreign_category_is_400(staff_client, other):
    foreign = CategoryFactory(retailer=other, name="SECRET-CAT")
    resp = staff_client.post(
        f"{BASE}/products", {"name": "P", "category": foreign.id, "unit": "1 kg"}, format="json"
    )
    assert resp.status_code == 400
    assert "category" in resp.json()["fields"]
    assert "SECRET-CAT" not in resp.content.decode()
    own = ProductFactory()
    assert (
        staff_client.patch(f"{BASE}/products/{own.pk}", {"category": foreign.id}, format="json")
    ).status_code == 400


@pytest.mark.parametrize("action", ["publish", "unpublish"])
def test_publish_foreign_flyer_is_404(staff_client, other, action):
    flyer = FlyerFactory(retailer=other)
    OfferFactory(flyer=flyer, product=ProductFactory(retailer=other))
    assert staff_client.post(f"{BASE}/flyers/{flyer.pk}/{action}").status_code == 404
    flyer.refresh_from_db()
    assert flyer.status == "draft"


@param
def test_platform_admin_gets_403_on_staff_routes(name):
    client = APIClient()
    client.force_authenticate(PlatformAdminFactory())
    route = RESOURCES[name][0]
    assert client.get(f"{BASE}/{route}").status_code == 403
    assert client.post(f"{BASE}/{route}", {}, format="json").status_code == 403


def test_payment_method_provider_unique_per_retailer_only(mine, other):
    from tests.factories import PASSWORD

    PaymentMethodFactory(retailer=other, provider="wave")
    user = StaffFactory()
    client = APIClient()
    client.force_authenticate(user)
    body = {
        "provider": "wave",
        "phone_number": "+2250700000009",
        "current_password": PASSWORD,
    }
    first = client.post(f"{BASE}/payment-methods", body, format="json")
    assert first.status_code == 201, first.json()
    assert client.post(f"{BASE}/payment-methods", body, format="json").status_code == 400


def test_category_slug_unique_within_one_retailer_via_api(staff_client, mine, other):
    CategoryFactory(retailer=mine, slug="dairy")
    dup = staff_client.post(f"{BASE}/categories", {"name": "D", "slug": "dairy"}, format="json")
    assert dup.status_code == 400
    assert "slug" in dup.json()["fields"]
    CategoryFactory(retailer=other, slug="bakery")
    ok = staff_client.post(f"{BASE}/categories", {"name": "B", "slug": "bakery"}, format="json")
    assert ok.status_code == 201, ok.json()


def test_product_ean_unique_within_one_retailer_via_api(staff_client, mine, other):
    category = CategoryFactory(retailer=mine)
    body = {"name": "P", "category": category.id, "unit": "1 kg", "ean": "4006381333931"}
    ProductFactory(retailer=mine, ean="4006381333931")
    dup = staff_client.post(f"{BASE}/products", body, format="json")
    assert dup.status_code == 400
    assert "ean" in dup.json()["fields"]
    ProductFactory(retailer=other, ean="5901234123457")
    ok = staff_client.post(f"{BASE}/products", {**body, "ean": "5901234123457"}, format="json")
    assert ok.status_code == 201, ok.json()
