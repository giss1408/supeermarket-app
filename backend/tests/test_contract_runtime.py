"""Real responses must conform to the generated OpenAPI schema (the Dart client's contract)."""

import copy
from typing import Any

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from drf_spectacular.generators import SchemaGenerator
from jsonschema import Draft202012Validator
from rest_framework.test import APIClient

from tests.factories import (
    CategoryFactory,
    FlyerFactory,
    ListItemFactory,
    OfferFactory,
    OpeningHoursFactory,
    ProductFactory,
    ShoppingListFactory,
    StaffFactory,
    StoreFactory,
    UserFactory,
)
from tests.uploads.conftest import make_image

pytestmark = pytest.mark.django_db


@pytest.fixture(scope="module")
def spec():
    return SchemaGenerator().get_schema(request=None, public=True)


def to_jsonschema(node: Any, spec: dict, mode: str) -> Any:
    """OpenAPI 3.0 schema -> JSON Schema, strict about undeclared properties.

    mode "response": writeOnly properties are removed (so their presence is reported as an
    undeclared property); "request" removes readOnly ones.
    """
    if isinstance(node, list):
        return [to_jsonschema(n, spec, mode) for n in node]
    if not isinstance(node, dict):
        return node
    if "$ref" in node:
        name = node["$ref"].rsplit("/", 1)[-1]
        return to_jsonschema(spec["components"]["schemas"][name], spec, mode)
    node = copy.copy(node)
    if len(node.get("allOf", [])) == 1:
        inner = to_jsonschema(node.pop("allOf")[0], spec, mode)
        node = {**inner, **node}
        node.pop("allOf", None)
        nullable = node.pop("nullable", False)
        return (
            {"anyOf": [inner, {"type": "null"}]}
            if nullable and "anyOf" not in inner
            else (
                {**inner, **{k: v for k, v in node.items() if k not in inner}}
                if not nullable
                else {"anyOf": [inner, {"type": "null"}]}
            )
        )
    nullable = node.pop("nullable", False)
    out: dict[str, Any] = {}
    skip = "writeOnly" if mode == "response" else "readOnly"
    for key, value in node.items():
        if key == "properties":
            out[key] = {
                k: to_jsonschema(v, spec, mode)
                for k, v in value.items()
                if not (isinstance(v, dict) and v.get(skip))
                and not (
                    isinstance(v, dict)
                    and "$ref" in v
                    and spec["components"]["schemas"][v["$ref"].rsplit("/", 1)[-1]].get(skip)
                )
            }
        elif key in ("items", "additionalProperties") and isinstance(value, dict):
            out[key] = to_jsonschema(value, spec, mode)
        elif key in ("oneOf", "anyOf", "allOf"):
            out[key] = to_jsonschema(value, spec, mode)
        else:
            out[key] = value
    if "required" in out:
        out["required"] = [r for r in out["required"] if r in out.get("properties", {})]
    if out.get("type") == "object" and "additionalProperties" not in out:
        out["additionalProperties"] = False
    if nullable:
        if "enum" in out:
            out["enum"] = [*out["enum"], None]
        return {"anyOf": [out, {"type": "null"}]}
    return out


def assert_conforms(resp, spec, path: str, method: str, status: int | None = None) -> None:
    status = status or resp.status_code
    operation = spec["paths"][path][method]
    assert resp.status_code == status, resp.content
    assert str(status) in operation["responses"], f"{method} {path}: {status} not documented"
    content = operation["responses"][str(status)].get("content", {})
    schema = content["application/json"]["schema"]
    validator = Draft202012Validator(to_jsonschema(schema, spec, "response"))
    errors = sorted(validator.iter_errors(resp.json()), key=lambda e: list(e.path))
    assert not errors, f"{method} {path} {status}: " + "; ".join(
        f"{'/'.join(map(str, e.path)) or '<root>'}: {e.message[:150]}" for e in errors
    )


def auth(user) -> APIClient:
    client = APIClient()
    client.force_authenticate(user)
    return client


def test_validator_reports_undeclared_and_missing_properties(spec):
    schema = to_jsonschema({"$ref": "#/components/schemas/Card"}, spec, "response")
    v = Draft202012Validator(schema)
    assert not list(v.iter_errors({"number": "1", "barcode_value": "1"}))
    assert list(v.iter_errors({"number": "1", "barcode_value": "1", "extra": 1}))
    assert list(v.iter_errors({"number": "1"}))


def test_auth_endpoints(spec):
    client = APIClient()
    res = client.post(
        "/api/v1/auth/register",
        {"email": "new@example.com", "password": "Str0ng-pass-word!", "name": "New"},
        format="json",
    )
    assert_conforms(res, spec, "/api/v1/auth/register", "post")
    res = client.post(
        "/api/v1/auth/login",
        {"email": "new@example.com", "password": "Str0ng-pass-word!"},
        format="json",
    )
    assert_conforms(res, spec, "/api/v1/auth/login", "post")
    refresh = res.json()["refresh"]
    res = client.post("/api/v1/auth/refresh", {"refresh": refresh}, format="json")
    assert_conforms(res, spec, "/api/v1/auth/refresh", "post")
    res = client.post("/api/v1/auth/logout", {"refresh": res.json()["refresh"]}, format="json")
    assert res.status_code == 204
    assert "204" in spec["paths"]["/api/v1/auth/logout"]["post"]["responses"]


def test_me_and_card(spec):
    client = auth(UserFactory())
    assert_conforms(client.get("/api/v1/me"), spec, "/api/v1/me", "get")
    assert_conforms(client.get("/api/v1/me/card"), spec, "/api/v1/me/card", "get")


def test_public_catalog_endpoints(spec):
    cat = CategoryFactory()
    product = ProductFactory(category=cat, ean="4000000000017")
    product.image = "products/p.jpg"
    product.save()
    flyer = FlyerFactory(status="published")
    OfferFactory(flyer=flyer, product=product, old_price="2.99", badge_text="-30%")
    OfferFactory(flyer=flyer)
    client = APIClient()
    assert_conforms(client.get("/api/v1/flyers/current"), spec, "/api/v1/flyers/current", "get")
    assert_conforms(client.get(f"/api/v1/flyers/{flyer.id}"), spec, "/api/v1/flyers/{id}", "get")
    assert_conforms(client.get("/api/v1/flyers"), spec, "/api/v1/flyers", "get")
    assert_conforms(client.get("/api/v1/offers"), spec, "/api/v1/offers", "get")
    assert_conforms(client.get("/api/v1/categories"), spec, "/api/v1/categories", "get")


def test_stores_with_and_without_location(spec):
    store = StoreFactory()
    OpeningHoursFactory(store=store, weekday=0, opens="08:00", closes="20:00")
    client = APIClient()
    res = client.get("/api/v1/stores")
    assert_conforms(res, spec, "/api/v1/stores", "get")
    assert res.json()["results"][0]["distance_km"] is None
    res = client.get("/api/v1/stores?lat=50.7&lng=7.1")
    assert_conforms(res, spec, "/api/v1/stores", "get")
    assert isinstance(res.json()["results"][0]["distance_km"], float)
    res = client.get(f"/api/v1/stores/{store.id}")
    assert_conforms(res, spec, "/api/v1/stores/{id}", "get")
    assert res.json()["opening_hours"]


def test_shopping_lists(spec):
    user = UserFactory()
    client = auth(user)
    shopping_list = ShoppingListFactory(user=user)
    product = ProductFactory()
    product.image = "products/p.jpg"
    product.save()
    ListItemFactory(list=shopping_list, product=product, text="")
    ListItemFactory(list=shopping_list, product=None, text="Milk")
    assert_conforms(client.get("/api/v1/lists"), spec, "/api/v1/lists", "get")
    res = client.post("/api/v1/lists", {"name": "Weekend"}, format="json")
    assert_conforms(res, spec, "/api/v1/lists", "post", 201)
    res = client.get(f"/api/v1/lists/{shopping_list.id}")
    assert_conforms(res, spec, "/api/v1/lists/{id}", "get")
    items = res.json()["items"]
    assert any(i["product"] and i["product"]["image"] for i in items)
    assert any(i["product"] is None for i in items)
    res = client.post(
        f"/api/v1/lists/{shopping_list.id}/items",
        {"product": product.id, "quantity": "2"},
        format="json",
    )
    assert_conforms(res, spec, "/api/v1/lists/{list_id}/items", "post", 201)
    res = client.patch(
        f"/api/v1/lists/{shopping_list.id}/items/{res.json()['id']}",
        {"checked": True},
        format="json",
    )
    assert_conforms(res, spec, "/api/v1/lists/{list_id}/items/{item_id}", "patch")


def test_staff_endpoints(spec):
    client = auth(StaffFactory())
    flyer = FlyerFactory()
    OfferFactory(flyer=flyer)
    ProductFactory()
    assert_conforms(
        client.get(f"/api/v1/staff/flyers/{flyer.id}"), spec, "/api/v1/staff/flyers/{id}", "get"
    )
    assert_conforms(client.get("/api/v1/staff/flyers"), spec, "/api/v1/staff/flyers", "get")
    assert_conforms(client.get("/api/v1/staff/products"), spec, "/api/v1/staff/products", "get")
    res = client.post(
        "/api/v1/staff/uploads/image",
        {"file": SimpleUploadedFile("a.jpg", make_image(), "image/jpeg")},
        format="multipart",
    )
    assert_conforms(res, spec, "/api/v1/staff/uploads/image", "post", 201)
