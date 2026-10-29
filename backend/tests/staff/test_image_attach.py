import pytest
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage

from tests.factories import CategoryFactory, FlyerFactory, ProductFactory
from tests.uploads.conftest import make_image

pytestmark = pytest.mark.django_db

BASE = "/api/v1/staff"
HEX = "a" * 32


@pytest.fixture
def uploaded():
    name = f"uploads/{HEX}.png"
    default_storage.save(name, ContentFile(make_image("PNG")))
    return name


def upload(client):
    from django.core.files.uploadedfile import SimpleUploadedFile

    resp = client.post(
        f"{BASE}/uploads/image",
        {"file": SimpleUploadedFile("a.png", make_image("PNG"), "image/png")},
        format="multipart",
    )
    assert resp.status_code == 201
    return resp.json()


def product_payload(**kw):
    return {"name": "Milk", "category": CategoryFactory().id, "unit": "l", **kw}


def test_product_create_with_image_name(staff_client):
    up = upload(staff_client)
    resp = staff_client.post(
        f"{BASE}/products", product_payload(image_name=up["name"]), format="json"
    )
    assert resp.status_code == 201, resp.json()
    assert resp.json()["image"] == up["url"]


def test_product_patch_image_name_then_clear_with_null(staff_client):
    p = ProductFactory()
    up = upload(staff_client)
    resp = staff_client.patch(f"{BASE}/products/{p.id}", {"image_name": up["name"]}, format="json")
    assert resp.status_code == 200
    assert resp.json()["image"] == up["url"]
    # omitted leaves unchanged
    resp = staff_client.patch(f"{BASE}/products/{p.id}", {"name": "New"}, format="json")
    assert resp.json()["image"] == up["url"]
    resp = staff_client.patch(f"{BASE}/products/{p.id}", {"image_name": None}, format="json")
    assert resp.status_code == 200
    assert resp.json()["image"] is None
    p.refresh_from_db()
    assert not p.image
    assert default_storage.exists(up["name"])  # file is not deleted


def test_flyer_cover_image_name_set_on_published_flyer_allowed(staff_client):
    flyer = FlyerFactory(status="published")
    up = upload(staff_client)
    resp = staff_client.patch(
        f"{BASE}/flyers/{flyer.id}", {"cover_image_name": up["name"]}, format="json"
    )
    assert resp.status_code == 200, resp.json()
    assert resp.json()["cover_image"] == up["url"]
    resp = staff_client.patch(
        f"{BASE}/flyers/{flyer.id}", {"valid_to": "2030-01-01"}, format="json"
    )
    assert resp.status_code == 400


def test_flyer_create_with_cover_and_nested_offers(staff_client):
    up = upload(staff_client)
    product = ProductFactory()
    resp = staff_client.post(
        f"{BASE}/flyers",
        {
            "title": "W",
            "valid_from": "2026-11-02",
            "valid_to": "2026-11-08",
            "cover_image_name": up["name"],
            "offers": [{"product": product.id, "price": "1.99"}],
        },
        format="json",
    )
    assert resp.status_code == 201, resp.json()
    assert resp.json()["cover_image"] == up["url"]
    assert len(resp.json()["offers"]) == 1


@pytest.mark.parametrize(
    "bad",
    [
        "uploads/../../etc/passwd",
        "products/x.png",
        f"uploads/{'A' * 32}.png",
        f"uploads/{HEX}.gif",
        f"uploads/{HEX}.png/",
        f"/uploads/{HEX}.png",
        f"uploads/{HEX}.png\n",
        "",
        123,
    ],
)
def test_image_name_must_match_pattern(staff_client, bad):
    p = ProductFactory()
    default_storage.save(f"uploads/{HEX}.png", ContentFile(make_image("PNG")))
    resp = staff_client.patch(f"{BASE}/products/{p.id}", {"image_name": bad}, format="json")
    assert resp.status_code == 400
    assert "image_name" in resp.json()["fields"]
    flyer = FlyerFactory()
    resp = staff_client.patch(f"{BASE}/flyers/{flyer.id}", {"cover_image_name": bad}, format="json")
    assert resp.status_code == 400
    assert "cover_image_name" in resp.json()["fields"]


def test_image_name_must_exist_in_storage(staff_client):
    p = ProductFactory()
    resp = staff_client.patch(
        f"{BASE}/products/{p.id}", {"image_name": f"uploads/{'b' * 32}.jpg"}, format="json"
    )
    assert resp.status_code == 400
    assert "image_name" in resp.json()["fields"]


def test_image_name_write_only_not_in_response(staff_client, uploaded):
    resp = staff_client.post(
        f"{BASE}/products", product_payload(image_name=uploaded), format="json"
    )
    assert "image_name" not in resp.json()
    flyer = FlyerFactory()
    resp = staff_client.patch(
        f"{BASE}/flyers/{flyer.id}", {"cover_image_name": uploaded}, format="json"
    )
    assert "cover_image_name" not in resp.json()


def test_read_image_url_is_absolute_after_attach(staff_client, uploaded):
    p = ProductFactory()
    staff_client.patch(f"{BASE}/products/{p.id}", {"image_name": uploaded}, format="json")
    resp = staff_client.get(f"{BASE}/products/{p.id}")
    assert resp.json()["image"] == f"http://testserver/media/{uploaded}"


def test_customer_cannot_set_image_name(customer_client, uploaded):
    p = ProductFactory()
    resp = customer_client.patch(f"{BASE}/products/{p.id}", {"image_name": uploaded}, format="json")
    assert resp.status_code == 403
    p.refresh_from_db()
    assert not p.image
