import re
from typing import Any

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.http import Http404
from rest_framework import exceptions
from rest_framework.response import Response
from rest_framework.views import exception_handler


class SubscriptionRequiredError(exceptions.PermissionDenied):
    """403 for an action that needs an active retailer subscription."""

    default_code = "subscription_required"


class StepUpRequiredError(exceptions.PermissionDenied):
    """403: a sensitive write needs a recent password proof at the auth service (the app calls
    /v1/step-up there, then retries)."""

    default_code = "step_up_required"
    default_detail = "step_up_required"


class SessionEndedError(exceptions.AuthenticationFailed):
    """401: the session was closed at the auth service."""

    default_code = "session_ended"
    default_detail = "session_ended"


class SsoUnavailableError(exceptions.APIException):
    """503: a money write needs the auth service's live check and it cannot be reached (fails
    closed)."""

    status_code = 503
    default_code = "sso_unavailable"
    default_detail = "sso_unavailable"


_CODES: list[tuple[type[Exception], str]] = [
    (StepUpRequiredError, "step_up_required"),
    (SessionEndedError, "session_ended"),
    (SsoUnavailableError, "sso_unavailable"),
    (exceptions.ValidationError, "validation_error"),
    (Http404, "not_found"),
    (exceptions.NotFound, "not_found"),
    (exceptions.NotAuthenticated, "not_authenticated"),
    (exceptions.AuthenticationFailed, "not_authenticated"),
    (SubscriptionRequiredError, "subscription_required"),
    (exceptions.PermissionDenied, "permission_denied"),
    (DjangoPermissionDenied, "permission_denied"),
    (exceptions.Throttled, "throttled"),
]


def _snake(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_") or "error"


def _code_for(exc: Exception) -> str:
    for cls, code in _CODES:
        if isinstance(exc, cls):
            return code
    return _snake(str(getattr(exc, "default_code", "error")))


def _messages(value: Any) -> list[str]:
    if isinstance(value, dict | list):
        items = value.values() if isinstance(value, dict) else value
        out: list[str] = []
        for item in items:
            out.extend(_messages(item))
        return out
    return [str(value)]


def custom_exception_handler(exc: Exception, context: dict[str, Any]) -> Response | None:
    response = exception_handler(exc, context)
    if response is None:
        return None
    code = _code_for(exc)
    fields: dict[str, list[str]] = {}
    if isinstance(exc, exceptions.ValidationError):
        detail = exc.detail
        if isinstance(detail, dict):
            fields = {str(k): _messages(v) for k, v in detail.items()}
        else:
            fields = {"non_field_errors": _messages(detail)}
        text = "Invalid input."
    elif isinstance(response.data, dict) and "detail" in response.data:
        text = str(response.data["detail"])
    else:
        text = str(getattr(exc, "default_detail", "Error."))
    response.data = {"code": code, "detail": text, "fields": fields}
    return response
