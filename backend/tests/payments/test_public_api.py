import pytest
from rest_framework.test import APIClient

from tests.factories import PaymentMethodFactory

pytestmark = pytest.mark.django_db

URL = "/api/v1/payment-methods"
FIELDS = {"provider", "phone_number", "display_name", "instructions", "updated_at"}


def test_public_lists_only_active_methods():
    PaymentMethodFactory(provider="wave")
    PaymentMethodFactory(provider="mtn_momo", phone_number="+2250100000003", is_active=False)
    res = APIClient().get(URL)
    assert res.status_code == 200
    assert [r["provider"] for r in res.json()["results"]] == ["wave"]


def test_public_includes_updated_at():
    method = PaymentMethodFactory()
    row = APIClient().get(URL).json()["results"][0]
    assert row["updated_at"]
    assert row["phone_number"] == method.phone_number


def test_public_exposes_only_declared_fields():
    PaymentMethodFactory(display_name="Wave CI", instructions="Send the total.")
    row = APIClient().get(URL).json()["results"][0]
    assert set(row) == FIELDS
    assert "is_active" not in row
    assert "id" not in row


def test_public_ignores_bad_bearer_token():
    PaymentMethodFactory()
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION="Bearer not-a-valid-token")
    assert client.get(URL).status_code == 200


def test_public_empty_page():
    res = APIClient().get(URL)
    assert res.status_code == 200
    assert res.json() == {"next": None, "previous": None, "results": []}


def test_public_ordered_by_provider():
    PaymentMethodFactory.create_all()
    providers = [r["provider"] for r in APIClient().get(URL).json()["results"]]
    assert providers == ["mtn_momo", "orange_money", "wave"]


@pytest.mark.parametrize("method", ["post", "put", "patch", "delete"])
def test_public_writes_are_405_in_standard_shape(method):
    res = getattr(APIClient(), method)(URL, {}, format="json")
    assert res.status_code == 405
    assert res.json()["code"] == "method_not_allowed"
    assert set(res.json()) == {"code", "detail", "fields"}
