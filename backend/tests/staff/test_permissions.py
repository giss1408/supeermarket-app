import pytest
from rest_framework_simplejwt.tokens import RefreshToken

from staff.urls import urlpatterns
from tests.factories import StaffFactory

pytestmark = pytest.mark.django_db

RESOURCES = ["flyers", "offers", "products", "categories", "stores"]
ROUTES = (
    [(m, f"/api/v1/staff/{r}") for r in RESOURCES for m in ("get", "post")]
    + [(m, f"/api/v1/staff/{r}/1") for r in RESOURCES for m in ("get", "put", "patch", "delete")]
    + [("post", "/api/v1/staff/flyers/1/publish"), ("post", "/api/v1/staff/flyers/1/unpublish")]
)


def _call(client, method, path):
    return getattr(client, method)(path, {}, format="json")


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_customer_gets_403_on_every_staff_route(customer_client, method, path):
    resp = _call(customer_client, method, path)
    assert resp.status_code == 403
    assert resp.json()["code"] == "permission_denied"
    assert set(resp.json()) == {"code", "detail", "fields"}


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_anonymous_gets_401_on_every_staff_route(anon_client, method, path):
    resp = _call(anon_client, method, path)
    assert resp.status_code == 401
    assert resp.json()["code"] == "not_authenticated"
    assert set(resp.json()) == {"code", "detail", "fields"}


@pytest.mark.parametrize("resource", RESOURCES)
def test_staff_user_allowed(staff_client, resource):
    assert staff_client.get(f"/api/v1/staff/{resource}").status_code == 200
    assert staff_client.get(f"/api/v1/staff/{resource}/999999").status_code == 404


def test_role_is_read_from_db_on_each_request(anon_client):
    user = StaffFactory()
    token = str(RefreshToken.for_user(user).access_token)
    anon_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    assert anon_client.get("/api/v1/staff/stores").status_code == 200
    user.role = "customer"
    user.save()
    assert anon_client.get("/api/v1/staff/stores").status_code == 403


def test_no_staff_creation_endpoint(staff_client):
    names = " ".join(str(p.pattern) for p in urlpatterns)
    for word in ("user", "role", "register", "promote", "staff"):
        assert word not in names.replace("^", "")
    for path in ("users", "staff", "roles"):
        assert staff_client.post(f"/api/v1/staff/{path}", {}, format="json").status_code == 404
