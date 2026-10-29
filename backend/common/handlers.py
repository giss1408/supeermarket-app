"""Django-level error handlers (unknown URLs, unhandled exceptions, CSRF failures).

DRF handles errors raised inside API views; these cover everything outside them, so the
standard ``{"code", "detail", "fields"}`` shape holds for every non-admin path. Under
``/admin/`` the stock HTML pages are kept so staff in a browser get readable pages.
"""

from django.http import HttpRequest, HttpResponse, JsonResponse
from django.views import defaults
from django.views.csrf import csrf_failure as default_csrf_failure


def _is_admin(request: HttpRequest) -> bool:
    return request.path.startswith("/admin/")


def _json(status: int, code: str, detail: str) -> JsonResponse:
    return JsonResponse({"code": code, "detail": detail, "fields": {}}, status=status)


def handler404(request: HttpRequest, exception: Exception | None = None) -> HttpResponse:
    if _is_admin(request):
        return defaults.page_not_found(request, exception)  # type: ignore[arg-type]
    return _json(404, "not_found", "Not found.")


def handler403(request: HttpRequest, exception: Exception | None = None) -> HttpResponse:
    if _is_admin(request):
        return defaults.permission_denied(request, exception)  # type: ignore[arg-type]
    return _json(403, "permission_denied", "You do not have permission to perform this action.")


def handler400(request: HttpRequest, exception: Exception | None = None) -> HttpResponse:
    if _is_admin(request):
        return defaults.bad_request(request, exception)  # type: ignore[arg-type]
    return _json(400, "bad_request", "Bad request.")


def handler500(request: HttpRequest) -> HttpResponse:
    if _is_admin(request):
        return defaults.server_error(request)
    return _json(500, "server_error", "Internal server error.")


def csrf_failure(request: HttpRequest, reason: str = "") -> HttpResponse:
    if _is_admin(request):
        return default_csrf_failure(request, reason)
    return _json(403, "csrf_failed", "CSRF verification failed.")
