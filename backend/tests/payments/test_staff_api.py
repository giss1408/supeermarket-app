import pytest
from rest_framework.test import APIClient
from rest_framework.throttling import ScopedRateThrottle

from payments.models import PaymentMethod, PaymentMethodChange
from tests.factories import PASSWORD, PaymentMethodFactory, StaffFactory, UserFactory

pytestmark = pytest.mark.django_db

LIST = "/api/v1/staff/payment-methods"
FIELDS = {
    "id",
    "provider",
    "phone_number",
    "display_name",
    "instructions",
    "is_active",
    "updated_at",
}
PUBLIC = "/api/v1/payment-methods"


@pytest.fixture
def staff():
    return StaffFactory()


@pytest.fixture
def client(staff):
    c = APIClient()
    c.force_authenticate(staff)
    return c


def detail(method) -> str:
    return f"{LIST}/{method.pk}"


def create_body(**extra):
    return {
        "provider": "wave",
        "phone_number": "07 01 02 03 04",
        "current_password": PASSWORD,
        **extra,
    }


# --- access -------------------------------------------------------------------------------


@pytest.mark.parametrize("method", ["get", "post"])
@pytest.mark.parametrize("who", ["anon", "customer"])
def test_anonymous_401_customer_403_on_collection(who, method):
    c = APIClient()
    if who == "customer":
        c.force_authenticate(UserFactory())
    res = getattr(c, method)(LIST, {}, format="json")
    assert res.status_code == (401 if who == "anon" else 403)
    assert set(res.json()) == {"code", "detail", "fields"}


@pytest.mark.parametrize("method", ["get", "patch", "put", "delete", "post"])
@pytest.mark.parametrize("who", ["anon", "customer"])
def test_anonymous_401_customer_403_on_every_route(who, method):
    m = PaymentMethodFactory()
    c = APIClient()
    if who == "customer":
        c.force_authenticate(UserFactory())
    res = getattr(c, method)(detail(m), {"current_password": PASSWORD}, format="json")
    assert res.status_code == (401 if who == "anon" else 403)
    assert res.json()["code"] == ("not_authenticated" if who == "anon" else "permission_denied")
    assert set(res.json()) == {"code", "detail", "fields"}


# --- read ---------------------------------------------------------------------------------


def test_list_includes_inactive_and_detail(client):
    PaymentMethodFactory(provider="wave")
    off = PaymentMethodFactory(provider="mtn_momo", phone_number="+2250100000003", is_active=False)
    res = client.get(LIST)
    assert res.status_code == 200
    rows = res.json()["results"]
    assert [r["provider"] for r in rows] == ["mtn_momo", "wave"]
    assert set(rows[0]) == FIELDS
    res = client.get(detail(off))
    assert res.status_code == 200
    assert res.json()["is_active"] is False


# --- create -------------------------------------------------------------------------------


@pytest.mark.parametrize("password", [None, "wrong-password"])
def test_create_requires_current_password(client, password):
    body = create_body()
    if password is None:
        del body["current_password"]
    else:
        body["current_password"] = password
    res = client.post(LIST, body, format="json")
    assert res.status_code == 400
    assert res.json()["code"] == "validation_error"
    assert "current_password" in res.json()["fields"]
    assert PaymentMethod.objects.count() == 0
    assert PaymentMethodChange.objects.count() == 0
    assert "wrong-password" not in res.content.decode()


def test_create_with_password_writes_audit_row(client, staff):
    res = client.post(
        LIST, create_body(display_name="Wave", instructions="Pay here"), format="json"
    )
    assert res.status_code == 201, res.content
    body = res.json()
    assert set(body) == FIELDS
    assert body["phone_number"] == "+2250701020304"
    assert "current_password" not in body
    assert PASSWORD not in res.content.decode()
    change = PaymentMethodChange.objects.get()
    assert change.changed_by == staff
    assert change.new_phone_number == "+2250701020304"


def test_duplicate_provider_400(client):
    PaymentMethodFactory(provider="wave")
    res = client.post(LIST, create_body(), format="json")
    assert res.status_code == 400
    assert "provider" in res.json()["fields"]
    assert PaymentMethod.objects.count() == 1


def test_duplicate_provider_integrity_race_maps_to_400(client, monkeypatch):
    from django.db import IntegrityError

    from payments import services

    def boom(**_):
        raise IntegrityError("duplicate key")

    monkeypatch.setattr(services, "create_method", boom)
    res = client.post(LIST, create_body(), format="json")
    assert res.status_code == 400
    assert "provider" in res.json()["fields"]


def test_create_invalid_provider_and_phone(client):
    res = client.post(LIST, create_body(provider="paypal", phone_number="abc"), format="json")
    assert res.status_code == 400
    assert {"provider", "phone_number"} <= set(res.json()["fields"])


def test_create_service_validation_error_becomes_400(client, monkeypatch):
    from django.core.exceptions import ValidationError

    from payments import services

    def boom(**_):
        raise ValidationError({"display_name": ["bad"]})

    monkeypatch.setattr(services, "create_method", boom)
    res = client.post(LIST, create_body(), format="json")
    assert res.status_code == 400
    assert res.json()["fields"] == {"display_name": ["bad"]}


def test_create_service_non_field_validation_error_becomes_400(client, monkeypatch):
    from django.core.exceptions import ValidationError

    from payments import services

    def boom(**_):
        raise ValidationError("nope")

    monkeypatch.setattr(services, "create_method", boom)
    res = client.post(LIST, create_body(), format="json")
    assert res.status_code == 400
    assert res.json()["fields"] == {"non_field_errors": ["nope"]}


def test_instructions_max_500(client):
    res = client.post(LIST, create_body(instructions="x" * 501), format="json")
    assert res.status_code == 400
    assert "instructions" in res.json()["fields"]


# --- patch --------------------------------------------------------------------------------


@pytest.mark.parametrize("raw", ["07 01 02 03 04", "+225 07 01 02 03 04", "00225 0701020304"])
def test_patch_number_requires_password_and_normalises(client, raw):
    m = PaymentMethodFactory()
    res = client.patch(detail(m), {"phone_number": raw}, format="json")
    assert res.status_code == 400
    assert "current_password" in res.json()["fields"]
    m.refresh_from_db()
    assert m.phone_number == "+2250700000001"
    assert PaymentMethodChange.objects.count() == 0
    res = client.patch(detail(m), {"phone_number": raw, "current_password": "nope"}, format="json")
    assert res.status_code == 400
    assert "current_password" in res.json()["fields"]
    res = client.patch(
        detail(m), {"phone_number": raw, "current_password": PASSWORD}, format="json"
    )
    assert res.status_code == 200, res.content
    assert res.json()["phone_number"] == "+2250701020304"
    assert "current_password" not in res.json()
    m.refresh_from_db()
    assert m.phone_number == "+2250701020304"
    assert PaymentMethodChange.objects.count() == 1


@pytest.mark.parametrize(
    "raw",
    ["01020304", "0701abcd04", "+33 6 01 02 03 04", "07 01 02 03 04 05 06", "", "+225" + "1" * 60],
)
def test_patch_invalid_number_400_field_error(client, raw):
    m = PaymentMethodFactory()
    res = client.patch(
        detail(m), {"phone_number": raw, "current_password": PASSWORD}, format="json"
    )
    assert res.status_code == 400
    assert "phone_number" in res.json()["fields"]
    m.refresh_from_db()
    assert m.phone_number == "+2250700000001"


def test_patch_instructions_only_writes_audit_row_and_noop_does_not(client):
    m = PaymentMethodFactory(instructions="old")
    res = client.patch(
        detail(m), {"instructions": "new", "current_password": PASSWORD}, format="json"
    )
    assert res.status_code == 200
    change = PaymentMethodChange.objects.get()
    assert (change.old_instructions, change.new_instructions) == ("old", "new")
    res = client.patch(
        detail(m), {"instructions": "new", "current_password": PASSWORD}, format="json"
    )
    assert res.status_code == 200
    assert PaymentMethodChange.objects.count() == 1


def test_provider_not_changeable_on_patch(client):
    m = PaymentMethodFactory(provider="wave")
    res = client.patch(
        detail(m), {"provider": "mtn_momo", "current_password": PASSWORD}, format="json"
    )
    assert res.status_code == 400
    assert "provider" in res.json()["fields"]
    m.refresh_from_db()
    assert m.provider == "wave"
    res = client.patch(
        detail(m),
        {"provider": "wave", "display_name": "W", "current_password": PASSWORD},
        format="json",
    )
    assert res.status_code == 200
    assert res.json()["display_name"] == "W"


def test_deactivate_via_patch_hides_from_public(client):
    m = PaymentMethodFactory()
    assert len(APIClient().get(PUBLIC).json()["results"]) == 1
    res = client.patch(detail(m), {"is_active": False, "current_password": PASSWORD}, format="json")
    assert res.status_code == 200
    assert res.json()["is_active"] is False
    assert APIClient().get(PUBLIC).json()["results"] == []
    assert len(client.get(LIST).json()["results"]) == 1


def test_patch_unknown_id_404(client):
    res = client.patch(f"{LIST}/999999", {"current_password": PASSWORD}, format="json")
    assert res.status_code == 404


@pytest.mark.parametrize("method", ["put", "delete"])
def test_put_and_delete_405(client, method):
    m = PaymentMethodFactory()
    res = getattr(client, method)(detail(m), {"current_password": PASSWORD}, format="json")
    assert res.status_code == 405
    assert set(res.json()) == {"code", "detail", "fields"}
    assert PaymentMethod.objects.count() == 1


def test_delete_absent_from_schema():
    from drf_spectacular.generators import SchemaGenerator

    spec = SchemaGenerator().get_schema(request=None, public=True)
    item = spec["paths"]["/api/v1/staff/payment-methods/{id}"]
    assert "delete" not in item
    assert "put" not in item


def test_current_password_never_in_response(client):
    m = PaymentMethodFactory()
    res = client.patch(
        detail(m), {"display_name": "x", "current_password": PASSWORD}, format="json"
    )
    assert PASSWORD not in res.content.decode()
    assert "current_password" not in res.json()
    assert "current_password" not in client.get(detail(m)).json()


# --- throttle -----------------------------------------------------------------------------


def test_throttle_rate_setting_default(settings):
    assert settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]["staff_sensitive"] == "5/min"


def test_step_up_throttled_after_five_attempts_per_user(client):
    m = PaymentMethodFactory()
    body = {"display_name": "a", "current_password": PASSWORD}
    for i in range(5):
        assert (
            client.patch(detail(m), {**body, "display_name": f"n{i}"}, format="json").status_code
            == 200
        )
    res = client.patch(detail(m), body, format="json")
    assert res.status_code == 429
    assert res.json()["code"] == "throttled"
    assert set(res.json()) == {"code", "detail", "fields"}
    other = APIClient()
    other.force_authenticate(StaffFactory())
    assert other.patch(detail(m), body, format="json").status_code == 200


def test_failed_attempts_count_toward_throttle(client):
    m = PaymentMethodFactory()
    for _ in range(5):
        res = client.patch(detail(m), {"current_password": "bad"}, format="json")
        assert res.status_code == 400
    assert client.post(LIST, create_body(), format="json").status_code == 429


def test_list_and_detail_not_throttled(client):
    m = PaymentMethodFactory()
    for _ in range(12):
        assert client.get(LIST).status_code == 200
        assert client.get(detail(m)).status_code == 200


def test_throttle_rate_is_read_from_the_setting(client, monkeypatch):
    monkeypatch.setitem(ScopedRateThrottle.THROTTLE_RATES, "staff_sensitive", "2/min")
    m = PaymentMethodFactory()
    body = {"display_name": "a", "current_password": PASSWORD}
    assert client.patch(detail(m), body, format="json").status_code == 200
    assert client.patch(detail(m), body, format="json").status_code == 200
    assert client.patch(detail(m), body, format="json").status_code == 429
