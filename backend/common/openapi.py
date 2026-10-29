"""OpenAPI helpers: the standard error component and the JWT bearer scheme name."""

from typing import Any

from drf_spectacular.extensions import OpenApiAuthenticationExtension

ERROR_REF = {"$ref": "#/components/schemas/Error"}
HTTP_METHODS = ("get", "put", "post", "patch", "delete", "head", "options", "trace")

ERROR_SCHEMA: dict[str, Any] = {
    "type": "object",
    "description": "Standard error shape returned by every endpoint on failure.",
    "properties": {
        "code": {"type": "string"},
        "detail": {"type": "string"},
        "fields": {
            "type": "object",
            "additionalProperties": {"type": "array", "items": {"type": "string"}},
        },
    },
    "required": ["code", "detail", "fields"],
}


def add_error_responses(result: dict[str, Any], generator: Any, request: Any, public: Any) -> Any:
    """Postprocessing hook: add the Error component and a default error response everywhere."""
    result.setdefault("components", {}).setdefault("schemas", {})["Error"] = ERROR_SCHEMA
    for item in result.get("paths", {}).values():
        for method in HTTP_METHODS:
            operation = item.get(method)
            if operation is not None:
                operation["responses"].setdefault(
                    "default",
                    {
                        "description": "Error in the standard shape",
                        "content": {"application/json": {"schema": ERROR_REF}},
                    },
                )
    return result


def sort_methods(result: dict[str, Any], generator: Any, request: Any, public: Any) -> Any:
    """Postprocessing hook: order the methods of each path canonically.

    Spectacular emits them in set order, which changes with PYTHONHASHSEED and would make the
    committed openapi.yaml differ from run to run.
    """
    for path, item in result.get("paths", {}).items():
        extras = {k: v for k, v in item.items() if k not in HTTP_METHODS}
        methods = {m: item[m] for m in HTTP_METHODS if m in item}
        result["paths"][path] = {**extras, **methods}
    return result


FORM_CONTENT_TYPES = ("application/x-www-form-urlencoded", "multipart/form-data")


def hide_form_content_types(
    result: dict[str, Any], generator: Any, request: Any, public: Any
) -> Any:
    """Postprocessing hook: document JSON only where JSON is accepted.

    DRF's default parsers also accept form bodies; the server still does, but advertising them
    makes client generators emit multi-content request handling. Operations without a JSON body
    (the multipart image upload) are left alone.
    """
    for item in result.get("paths", {}).values():
        for method in HTTP_METHODS:
            content = (item.get(method) or {}).get("requestBody", {}).get("content")
            if content and "application/json" in content:
                for media_type in FORM_CONTENT_TYPES:
                    content.pop(media_type, None)
    return result


class BearerAuthScheme(OpenApiAuthenticationExtension):
    """Publish simplejwt's JWTAuthentication as the ``bearerAuth`` security scheme."""

    target_class = "rest_framework_simplejwt.authentication.JWTAuthentication"
    name = "bearerAuth"
    priority = 1

    def get_security_definition(self, auto_schema: Any) -> dict[str, str]:
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}
