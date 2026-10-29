import pytest
from rest_framework.test import APIClient

from shopping.models import ListItem, ShoppingList
from tests.factories import (
    ListItemFactory,
    ProductFactory,
    ShoppingListFactory,
    StaffFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db

LISTS = "/api/v1/lists"


@pytest.fixture
def user():
    return UserFactory()


@pytest.fixture
def client(user):
    c = APIClient()
    c.force_authenticate(user)
    return c


def assert_error_shape(resp, status, code=None):
    assert resp.status_code == status
    assert set(resp.data) == {"code", "detail", "fields"}
    if code:
        assert resp.data["code"] == code


def bump(lst, iso):
    ShoppingList.objects.filter(pk=lst.pk).update(updated_at=iso)


def test_empty_lists_page(client):
    resp = client.get(LISTS)
    assert resp.status_code == 200
    assert resp.data["results"] == []
    assert resp.data["next"] is None


def test_create_list_and_representation(client, user):
    resp = client.post(LISTS, {"name": "Weekly"}, format="json")
    assert resp.status_code == 201
    assert resp.data["name"] == "Weekly"
    assert resp.data["items"] == []
    assert ShoppingList.objects.get(pk=resp.data["id"]).user == user
    listing = client.get(LISTS).data["results"][0]
    assert set(listing) == {"id", "name", "item_count", "created_at", "updated_at"}
    assert listing["item_count"] == 0


def test_create_list_requires_name(client):
    resp = client.post(LISTS, {}, format="json")
    assert_error_shape(resp, 400)
    assert "name" in resp.data["fields"]


def test_list_cannot_set_user(client, user):
    other = UserFactory()
    resp = client.post(LISTS, {"name": "x", "user": other.id}, format="json")
    assert resp.status_code == 201
    assert ShoppingList.objects.get(pk=resp.data["id"]).user == user


def test_list_only_returns_own_lists(client, user):
    mine = ShoppingListFactory(user=user)
    ShoppingListFactory()
    resp = client.get(LISTS)
    assert [r["id"] for r in resp.data["results"]] == [mine.id]


def test_staff_user_can_have_lists():
    staff = StaffFactory()
    c = APIClient()
    c.force_authenticate(staff)
    resp = c.post(LISTS, {"name": "Staff"}, format="json")
    assert resp.status_code == 201
    assert [r["id"] for r in c.get(LISTS).data["results"]] == [resp.data["id"]]


def test_patch_list_name(client, user):
    lst = ShoppingListFactory(user=user)
    resp = client.patch(f"{LISTS}/{lst.id}", {"name": "New"}, format="json")
    assert resp.status_code == 200
    assert resp.data["name"] == "New"
    assert "items" in resp.data


def test_delete_list(client, user):
    lst = ShoppingListFactory(user=user)
    assert client.delete(f"{LISTS}/{lst.id}").status_code == 204
    assert not ShoppingList.objects.filter(pk=lst.pk).exists()


def test_put_not_allowed(client, user):
    lst = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst)
    for url in (f"{LISTS}/{lst.id}", f"{LISTS}/{lst.id}/items/{item.id}"):
        resp = client.put(url, {"name": "x", "text": "x"}, format="json")
        assert_error_shape(resp, 405)


def test_deleting_list_deletes_items(client, user):
    lst = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst)
    assert client.delete(f"{LISTS}/{lst.id}").status_code == 204
    assert not ListItem.objects.filter(pk=item.pk).exists()


def test_list_response_has_items_ordered_unchecked_first(client, user):
    lst = ShoppingListFactory(user=user)
    checked = ListItemFactory(list=lst, checked=True)
    first = ListItemFactory(list=lst)
    second = ListItemFactory(list=lst)
    resp = client.get(f"{LISTS}/{lst.id}")
    assert [i["id"] for i in resp.data["items"]] == [first.id, second.id, checked.id]
    assert client.get(LISTS).data["results"][0]["item_count"] == 3


def test_item_representation_with_product(client, user):
    lst = ShoppingListFactory(user=user)
    product = ProductFactory()
    ListItemFactory(list=lst, product=product, text="", quantity=3)
    item = client.get(f"{LISTS}/{lst.id}").data["items"][0]
    assert set(item) == {
        "id",
        "product",
        "text",
        "quantity",
        "checked",
        "created_at",
        "updated_at",
    }
    assert item["product"] == {
        "id": product.id,
        "name": product.name,
        "unit": product.unit,
        "image": None,
    }
    assert item["quantity"] == 3


def test_product_image_is_absolute_url(client, user):
    lst = ShoppingListFactory(user=user)
    product = ProductFactory(image="products/a.jpg")
    ListItemFactory(list=lst, product=product, text="")
    image = client.get(f"{LISTS}/{lst.id}").data["items"][0]["product"]["image"]
    assert image.startswith("http://testserver/")
    assert image.endswith("products/a.jpg")


def test_add_item_with_text_and_product(client, user):
    lst = ShoppingListFactory(user=user)
    product = ProductFactory()
    r1 = client.post(f"{LISTS}/{lst.id}/items", {"text": "bread"}, format="json")
    assert r1.status_code == 201
    assert r1.data["text"] == "bread" and r1.data["quantity"] == 1 and r1.data["product"] is None
    r2 = client.post(
        f"{LISTS}/{lst.id}/items", {"product": product.id, "quantity": 2}, format="json"
    )
    assert r2.status_code == 201
    assert r2.data["product"]["id"] == product.id


def test_item_requires_product_or_text_api(client, user):
    lst = ShoppingListFactory(user=user)
    for body in ({}, {"text": ""}, {"text": "   "}, {"quantity": 2}):
        resp = client.post(f"{LISTS}/{lst.id}/items", body, format="json")
        assert_error_shape(resp, 400)
        assert "non_field_errors" in resp.data["fields"]
    item = ListItemFactory(list=lst, text="milk")
    resp = client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"text": ""}, format="json")
    assert_error_shape(resp, 400)
    assert "non_field_errors" in resp.data["fields"]
    item.refresh_from_db()
    assert item.text == "milk"


def test_patch_item_text_to_empty_ok_when_product_present(client, user):
    lst = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst, product=ProductFactory(), text="x")
    resp = client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"text": ""}, format="json")
    assert resp.status_code == 200


def test_unknown_product_id_is_field_error(client, user):
    lst = ShoppingListFactory(user=user)
    resp = client.post(f"{LISTS}/{lst.id}/items", {"product": 999999}, format="json")
    assert_error_shape(resp, 400)
    assert "product" in resp.data["fields"]


def test_quantity_zero_rejected(client, user):
    lst = ShoppingListFactory(user=user)
    for q in (0, 1000):
        resp = client.post(f"{LISTS}/{lst.id}/items", {"text": "a", "quantity": q}, format="json")
        assert_error_shape(resp, 400)
        assert "quantity" in resp.data["fields"]
    item = ListItemFactory(list=lst)
    resp = client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"quantity": 0}, format="json")
    assert resp.status_code == 400
    ok = client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"quantity": 999}, format="json")
    assert ok.status_code == 200


def test_patch_and_delete_item(client, user):
    lst = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst)
    resp = client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"checked": True}, format="json")
    assert resp.status_code == 200 and resp.data["checked"] is True
    assert client.delete(f"{LISTS}/{lst.id}/items/{item.id}").status_code == 204
    assert not ListItem.objects.filter(pk=item.pk).exists()


def test_item_list_field_not_writable(client, user):
    lst = ShoppingListFactory(user=user)
    other = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst)
    client.patch(f"{LISTS}/{lst.id}/items/{item.id}", {"list": other.id}, format="json")
    item.refresh_from_db()
    assert item.list_id == lst.id


def test_item_change_bumps_list_updated_at(client, user):
    lst = ShoppingListFactory(user=user)
    old = "2020-01-01T00:00:00Z"

    def updated():
        return ShoppingList.objects.get(pk=lst.pk).updated_at.isoformat()

    bump(lst, old)
    created = client.post(f"{LISTS}/{lst.id}/items", {"text": "a"}, format="json")
    assert updated() > "2021"
    bump(lst, old)
    client.patch(f"{LISTS}/{lst.id}/items/{created.data['id']}", {"checked": True}, format="json")
    assert updated() > "2021"
    bump(lst, old)
    client.delete(f"{LISTS}/{lst.id}/items/{created.data['id']}")
    assert updated() > "2021"


def test_user_cannot_read_other_users_list(client):
    lst = ShoppingListFactory()
    resp = client.get(f"{LISTS}/{lst.id}")
    assert_error_shape(resp, 404)


def test_user_cannot_modify_or_delete_other_users_list(client):
    lst = ShoppingListFactory(name="orig")
    assert_error_shape(client.patch(f"{LISTS}/{lst.id}", {"name": "x"}, format="json"), 404)
    assert_error_shape(client.delete(f"{LISTS}/{lst.id}"), 404)
    lst.refresh_from_db()
    assert lst.name == "orig"


def test_user_cannot_add_item_to_other_users_list(client):
    lst = ShoppingListFactory()
    resp = client.post(f"{LISTS}/{lst.id}/items", {"text": "x"}, format="json")
    assert_error_shape(resp, 404)
    assert not lst.items.exists()


def test_user_cannot_touch_other_users_item_even_via_own_list_url(client, user):
    own = ShoppingListFactory(user=user)
    foreign = ListItemFactory(text="theirs")
    url = f"{LISTS}/{own.id}/items/{foreign.id}"
    assert_error_shape(client.patch(url, {"text": "x"}, format="json"), 404)
    assert_error_shape(client.delete(url), 404)
    # and via the foreign list url
    url2 = f"{LISTS}/{foreign.list_id}/items/{foreign.id}"
    assert_error_shape(client.patch(url2, {"text": "x"}, format="json"), 404)
    assert_error_shape(client.delete(url2), 404)
    foreign.refresh_from_db()
    assert foreign.text == "theirs"


def test_anonymous_gets_401():
    c = APIClient()
    lst = ShoppingListFactory()
    item = ListItemFactory(list=lst)
    calls = [
        ("get", LISTS),
        ("post", LISTS),
        ("get", f"{LISTS}/{lst.id}"),
        ("patch", f"{LISTS}/{lst.id}"),
        ("delete", f"{LISTS}/{lst.id}"),
        ("post", f"{LISTS}/{lst.id}/items"),
        ("patch", f"{LISTS}/{lst.id}/items/{item.id}"),
        ("delete", f"{LISTS}/{lst.id}/items/{item.id}"),
    ]
    for method, url in calls:
        resp = getattr(c, method)(url)
        assert_error_shape(resp, 401)


def test_updated_since_returns_only_newer_lists(client, user):
    old = ShoppingListFactory(user=user)
    edge = ShoppingListFactory(user=user)
    new = ShoppingListFactory(user=user)
    bump(old, "2026-01-01T00:00:00Z")
    bump(edge, "2026-06-01T00:00:00Z")
    bump(new, "2026-06-01T00:00:01Z")
    resp = client.get(LISTS, {"updated_since": "2026-06-01T00:00:00Z"})
    assert [r["id"] for r in resp.data["results"]] == [new.id]


def test_updated_since_invalid_returns_400_field_error(client):
    resp = client.get(LISTS, {"updated_since": "yesterday"})
    assert_error_shape(resp, 400)
    assert "updated_since" in resp.data["fields"]


def test_updated_since_naive_datetime_treated_as_utc(client, user):
    a = ShoppingListFactory(user=user)
    b = ShoppingListFactory(user=user)
    bump(a, "2026-06-01T09:59:59Z")
    bump(b, "2026-06-01T10:00:01Z")
    resp = client.get(LISTS, {"updated_since": "2026-06-01T10:00:00"})
    assert [r["id"] for r in resp.data["results"]] == [b.id]


def test_lists_ordered_by_updated_desc(client, user):
    a = ShoppingListFactory(user=user)
    b = ShoppingListFactory(user=user)
    bump(a, "2026-01-01T00:00:00Z")
    bump(b, "2026-02-01T00:00:00Z")
    assert [r["id"] for r in client.get(LISTS).data["results"]] == [b.id, a.id]


def test_deleting_account_deletes_lists(client, user):
    lst = ShoppingListFactory(user=user)
    item = ListItemFactory(list=lst)
    survivor = ShoppingListFactory()
    resp = client.delete("/api/v1/me")
    assert resp.status_code == 204
    assert not ShoppingList.objects.filter(pk=lst.pk).exists()
    assert not ListItem.objects.filter(pk=item.pk).exists()
    assert ShoppingList.objects.filter(pk=survivor.pk).exists()
