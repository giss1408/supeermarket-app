import copy
from pathlib import Path

import pytest
import yaml
from django.core.management import call_command
from rest_framework.test import APIClient

from common.openapi import add_error_responses, hide_form_content_types, sort_methods

COMMITTED = Path(__file__).resolve().parent.parent / "openapi.yaml"
REGENERATE = (
    "cd backend && python manage.py spectacular --file openapi.yaml --validate --fail-on-warn"
)
PRIVATE_PREFIXES = ("/api/v1/staff/", "/api/v1/me", "/api/v1/lists")
HTTP_METHODS = {"get", "put", "post", "patch", "delete", "head", "options"}


@pytest.fixture(scope="module")
def schema():
    return yaml.safe_load(COMMITTED.read_text())


def operations(schema):
    for path, item in schema["paths"].items():
        for method, op in item.items():
            if method in HTTP_METHODS:
                yield path, method, op


def test_committed_openapi_matches_generated(tmp_path, settings):
    out = tmp_path / "generated.yaml"
    call_command("spectacular", file=str(out), validate=True, fail_on_warn=True)
    assert out.read_text() == COMMITTED.read_text(), (
        f"backend/openapi.yaml is out of date. Regenerate it with:\n  {REGENERATE}"
    )


def test_schema_endpoint_is_public_and_serves_yaml_and_json(db):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION="Bearer not-a-valid-token")
    res = client.get("/api/schema/")
    assert res.status_code == 200
    assert res["Content-Type"].startswith("application/vnd.oai.openapi;")
    assert yaml.safe_load(res.content)["openapi"].startswith("3.")
    res = client.get("/api/schema/?format=json")
    assert res.status_code == 200
    assert res["Content-Type"].startswith("application/vnd.oai.openapi+json")
    assert res.json()["info"]["title"] == "Supermarket API"


def test_schema_has_bearer_auth_scheme(schema):
    scheme = schema["components"]["securitySchemes"]["bearerAuth"]
    assert scheme == {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
    assert "jwtAuth" not in schema["components"]["securitySchemes"]


def test_every_operation_has_default_error_response_referencing_Error(schema):
    seen = 0
    for path, method, op in operations(schema):
        default = op["responses"].get("default")
        assert default is not None, f"{method} {path}"
        assert default["content"]["application/json"]["schema"] == {
            "$ref": "#/components/schemas/Error"
        }
        seen += 1
    assert seen > 30


def test_error_component_shape(schema):
    error = schema["components"]["schemas"]["Error"]
    assert error["type"] == "object"
    assert set(error["required"]) == {"code", "detail", "fields"}
    assert error["properties"]["code"]["type"] == "string"
    assert error["properties"]["detail"]["type"] == "string"
    fields = error["properties"]["fields"]
    assert fields["type"] == "object"
    assert fields["additionalProperties"] == {"type": "array", "items": {"type": "string"}}


def test_operation_ids_unique(schema):
    ids = [op["operationId"] for _, _, op in operations(schema)]
    assert len(ids) == len(set(ids))


def test_staff_routes_require_security_and_public_routes_do_not(schema):
    for path, method, op in operations(schema):
        security = op.get("security")
        if path.startswith(PRIVATE_PREFIXES):
            assert security and {"bearerAuth": []} in security, f"{method} {path}"
        elif method == "get":
            assert security in (None, [], [{}]), f"{method} {path} should be public"


def test_write_only_image_name_only_in_request_schemas_and_not_in_responses(schema):
    schemas = schema["components"]["schemas"]
    assert "image_name" in schemas["StaffProductRequest"]["properties"]
    assert "image_name" not in schemas["StaffProduct"]["properties"]
    assert "role" not in schemas["RegisterRequest"]["properties"]
    assert "password" not in schemas["Register"]["properties"]


def test_add_error_responses_hook_on_synthetic_schema():
    result = {
        "paths": {
            "/a": {
                "get": {"responses": {"200": {"description": "ok"}}},
                "post": {
                    "responses": {"default": {"description": "custom"}},
                },
                "parameters": [],
            }
        },
        "components": {"schemas": {}},
    }
    out = add_error_responses(copy.deepcopy(result), None, None, True)
    ref = {"$ref": "#/components/schemas/Error"}
    assert out["paths"]["/a"]["get"]["responses"]["default"] == {
        "description": "Error in the standard shape",
        "content": {"application/json": {"schema": ref}},
    }
    assert out["paths"]["/a"]["post"]["responses"]["default"] == {"description": "custom"}
    assert out["paths"]["/a"]["parameters"] == []
    assert out["components"]["schemas"]["Error"]["required"] == ["code", "detail", "fields"]


def test_sort_methods_hook_orders_methods_canonically():
    result = {"paths": {"/a": {"delete": {}, "parameters": [], "get": {}, "patch": {}, "post": {}}}}
    out = sort_methods(result, None, None, True)
    assert list(out["paths"]["/a"]) == ["parameters", "get", "post", "patch", "delete"]


@pytest.mark.parametrize("seed", ["1", "2", "3"])
def test_generation_is_independent_of_hash_seed(seed):
    import os
    import subprocess
    import sys

    env = {**os.environ, "PYTHONHASHSEED": seed}
    out = subprocess.run(
        [sys.executable, "manage.py", "spectacular"],
        cwd=COMMITTED.parent,
        env=env,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    assert out == COMMITTED.read_text()


def test_shopping_list_detail_items_are_typed_list_items(schema):
    schemas = schema["components"]["schemas"]
    items = schemas["ShoppingListDetail"]["properties"]["items"]
    assert items["type"] == "array"
    assert items["items"] == {"$ref": "#/components/schemas/ListItem"}
    assert {"id", "product", "text", "checked"} <= set(schemas["ListItem"]["properties"])
    product = schemas["ListItem"]["properties"]["product"]
    assert product["nullable"] is True
    assert product["allOf"] == [{"$ref": "#/components/schemas/ProductSummary"}]
    assert schemas["ListItemRequest"]["properties"]["product"] == {
        "type": "integer",
        "nullable": True,
    }


FORM_TYPES = ("application/x-www-form-urlencoded", "multipart/form-data")


def _body(*types):
    return {"requestBody": {"content": {t: {"schema": {"type": "object"}} for t in types}}}


def test_hide_form_content_types_hook_on_synthetic_schema():
    json_type = "application/json"
    result = {
        "paths": {
            "/a": {
                "post": _body(json_type, *FORM_TYPES),
                "put": _body("multipart/form-data"),
                "patch": _body(json_type),
                "get": {"responses": {}},
                "parameters": [],
            }
        }
    }
    item = hide_form_content_types(result, None, None, True)["paths"]["/a"]
    assert list(item["post"]["requestBody"]["content"]) == [json_type]
    assert list(item["put"]["requestBody"]["content"]) == ["multipart/form-data"]
    assert list(item["patch"]["requestBody"]["content"]) == [json_type]
    assert "requestBody" not in item["get"]


def test_only_the_upload_lists_form_content_types(schema):
    for path, method, op in operations(schema):
        content = op.get("requestBody", {}).get("content", {})
        if "application/json" in content:
            assert not set(content) & set(FORM_TYPES), f"{method} {path}"
    upload = schema["paths"]["/api/v1/staff/uploads/image"]["post"]
    content = upload["requestBody"]["content"]
    assert list(content) == ["multipart/form-data"]
    ref = content["multipart/form-data"]["schema"]["$ref"].rsplit("/", 1)[-1]
    file_prop = schema["components"]["schemas"][ref]["properties"]["file"]
    assert file_prop["format"] == "binary"
