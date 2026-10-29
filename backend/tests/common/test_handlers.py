import pytest
from django.http import HttpResponse
from django.test import Client, RequestFactory
from django.urls import path

from common import handlers
from config import urls as root_urls


def boom(request):
    raise RuntimeError("secret internal detail")


urlpatterns = [
    path("api/v1/boom", boom),
    path("admin/boom/", boom),
    path("ok", lambda request: HttpResponse("ok")),
    *root_urls.urlpatterns,
]
handler400 = root_urls.handler400
handler403 = root_urls.handler403
handler404 = root_urls.handler404
handler500 = root_urls.handler500

pytestmark = pytest.mark.urls(__name__)

SHAPE = {"code", "detail", "fields"}


@pytest.fixture(autouse=True)
def _no_debug(settings):
    settings.DEBUG = False


@pytest.mark.parametrize("url", ["/api/v1/does-not-exist", "/nope"])
def test_unknown_path_is_json_404(url):
    resp = Client().get(url)
    assert resp.status_code == 404
    assert resp["Content-Type"].startswith("application/json")
    assert resp.json() == {"code": "not_found", "detail": "Not found.", "fields": {}}


@pytest.mark.django_db
def test_admin_unknown_path_keeps_html_404():
    from tests.factories import UserFactory

    client = Client()
    client.force_login(UserFactory(is_staff=True, is_superuser=True))
    resp = client.get("/admin/nope/")
    assert resp.status_code == 404
    assert resp["Content-Type"].startswith("text/html")


def test_unhandled_exception_is_json_500_without_leak():
    resp = Client(raise_request_exception=False).get("/api/v1/boom")
    assert resp.status_code == 500
    assert resp["Content-Type"].startswith("application/json")
    body = resp.json()
    assert set(body) == SHAPE
    assert body["code"] == "server_error"
    assert "secret" not in resp.content.decode()
    assert "Traceback" not in resp.content.decode()


def test_admin_unhandled_exception_keeps_html_500():
    resp = Client(raise_request_exception=False).get("/admin/boom/")
    assert resp.status_code == 500
    assert resp["Content-Type"].startswith("text/html")


def test_csrf_failure_is_json_403():
    client = Client(enforce_csrf_checks=True)
    resp = client.post("/ok", {"a": "b"})
    assert resp.status_code == 403
    assert resp.json() == {
        "code": "csrf_failed",
        "detail": "CSRF verification failed.",
        "fields": {},
    }


def test_admin_csrf_failure_keeps_html():
    resp = Client(enforce_csrf_checks=True).post("/admin/login/", {"a": "b"})
    assert resp.status_code == 403
    assert resp["Content-Type"].startswith("text/html")


def test_400_and_403_handlers_shape():
    rf = RequestFactory()
    bad = handlers.handler400(rf.get("/api/v1/x"))
    assert bad.status_code == 400 and b'"bad_request"' in bad.content
    denied = handlers.handler403(rf.get("/api/v1/x"))
    assert denied.status_code == 403 and b'"permission_denied"' in denied.content
    assert handlers.handler400(rf.get("/admin/x")).status_code == 400
    assert handlers.handler403(rf.get("/admin/x")).status_code == 403
