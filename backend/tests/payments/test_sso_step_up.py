"""Staff who signed in through the auth service have no local password: payment-method writes (where
customers pay) need a password re-proved
within 5 minutes AT AUTH and a live session there, and fail closed when auth cannot answer."""

import time
import uuid

import pytest
from django.core.management import call_command
from rest_framework.test import APIClient

from payments.models import PaymentMethod
from tests.factories import RetailerFactory
from tests.sso_helpers import token

pytestmark = pytest.mark.django_db
LIST = "/api/v1/staff/payment-methods"
BODY = {"provider": "wave", "phone_number": "07 01 02 03 04"}


@pytest.fixture
def staff_token(sso_on):
    retailer = RetailerFactory()
    sub = uuid.uuid4()
    call_command(
        "link_sso_user", auth_user_id=str(sub), role="retailer_staff", retailer=retailer.slug
    )
    return lambda **over: token(sub, role="retailer_staff", **over), retailer


def post(t, body=None):
    c = APIClient()
    return c.post(LIST, body or BODY, format="json", HTTP_AUTHORIZATION=f"Bearer {t}")


def test_a_fresh_password_proof_and_a_live_session_let_staff_write_without_a_local_password(
    staff_token, monkeypatch
):
    make, retailer = staff_token
    monkeypatch.setattr("accounts.sso.session_alive", lambda t: True)
    r = post(make())
    assert r.status_code == 201, r.content
    method = PaymentMethod.objects.get(retailer=retailer)
    assert method.provider == "wave"
    change = method.changes.get()
    assert change.changed_by_email.startswith(
        "sso:"
    )  # the trail names her by her auth id: she has no e-mail here


def test_a_stale_proof_asks_for_a_step_up_with_its_own_code(staff_token, monkeypatch):
    make, _ = staff_token
    monkeypatch.setattr("accounts.sso.session_alive", lambda t: True)
    r = post(make(auth_time=int(time.time()) - 900))
    assert r.status_code == 403 and r.json()["code"] == "step_up_required"
    assert PaymentMethod.objects.count() == 0


def test_a_session_closed_at_auth_is_refused_even_with_a_fresh_token(staff_token, monkeypatch):
    make, _ = staff_token
    monkeypatch.setattr("accounts.sso.session_alive", lambda t: False)
    r = post(make())
    assert r.status_code == 401 and r.json()["code"] == "session_ended"
    assert PaymentMethod.objects.count() == 0


def test_when_auth_cannot_answer_a_money_write_fails_closed_unless_the_owner_says_otherwise(
    staff_token, monkeypatch, settings
):
    make, _ = staff_token
    monkeypatch.setattr("accounts.sso.session_alive", lambda t: None)
    r = post(make())
    assert r.status_code == 503 and r.json()["code"] == "sso_unavailable"
    settings.SSO_MONEY_FAIL_CLOSED = False
    r2 = post(make(), {**BODY, "provider": "orange_money"})
    assert r2.status_code == 201, r2.content


def test_reading_payment_methods_needs_no_step_up(staff_token):
    make, _ = staff_token
    assert (
        APIClient()
        .get(LIST, HTTP_AUTHORIZATION=f"Bearer {make(auth_time=int(time.time()) - 9000)}")
        .status_code
        == 200
    )


def test_the_apps_own_staff_still_have_to_type_their_password(sso_on):
    from tests.factories import PASSWORD, StaffFactory

    staff = StaffFactory()
    c = APIClient()
    c.force_authenticate(staff)
    assert (
        c.post(LIST, BODY, format="json").status_code == 400
    )  # current_password required, as before
    assert c.post(LIST, {**BODY, "current_password": PASSWORD}, format="json").status_code == 201
