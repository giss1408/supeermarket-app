"""The platform dashboard with the auth service: the admin signs in AT auth (phone + password +
authenticator code), the first staff member of a
new retailer is enrolled by phone (WhatsApp activation, own password), and a dashboard session ends
when the auth session does."""

import uuid

import pytest
from django.core.management import call_command
from django.test import Client
from django.urls import reverse

from accounts.models import User
from retailers.models import Retailer
from tests.sso_helpers import token

pytestmark = pytest.mark.django_db


@pytest.fixture
def dashboard(sso_on, settings, monkeypatch):
    settings.LEGACY_AUTH_ENABLED = False
    admin_sub = uuid.uuid4()
    call_command("link_sso_user", auth_user_id=str(admin_sub), role="platform_admin", name="Boss")
    state = {
        "login": (200, {"access_token": token(admin_sub, role="platform_admin")}),
        "alive": True,
        "enrol": None,
        "removed": [],
    }
    monkeypatch.setattr("accounts.sso.login_at_auth", lambda phone, password, totp: state["login"])
    monkeypatch.setattr("accounts.sso.sid_alive", lambda sid: state["alive"])

    def enrol(phone, name, role="retailer_staff"):
        if isinstance(state["enrol"], str):
            raise sso_on.EnrolError(state["enrol"])
        return str(state["enrol"] or uuid.uuid4())

    monkeypatch.setattr("accounts.sso.enrol_staff", enrol)
    monkeypatch.setattr(
        "accounts.sso.remove_staff", lambda uid: state["removed"].append(str(uid)) or True
    )
    return state


FORM = {"phone": "07 01 02 03 04", "password": "x" * 10, "totp": "123456"}


def signed_in() -> Client:
    c = Client()
    assert c.post(reverse("platform:login"), FORM).status_code == 302
    return c


def test_the_admin_signs_in_at_auth_and_gets_a_dashboard_session(dashboard):
    c = signed_in()
    assert c.get(reverse("platform:retailer_list")).status_code == 200
    assert c.session["sso_sid"] == "sid-12345678"


def test_failures_at_auth_are_said_in_words(dashboard):
    for detail, words in (
        ("invalid_credentials", "incorrect"),
        ("invalid_totp", "déjà utilisé"),
        ("login_locked", "15 minutes"),
    ):
        dashboard["login"] = (401, {"detail": detail})
        r = Client().post(reverse("platform:login"), FORM)
        assert r.status_code == 200 and words in r.content.decode()
        assert "_auth_user_id" not in r.wsgi_request.session


def test_only_a_linked_platform_admin_gets_in(dashboard):
    dashboard["login"] = (
        200,
        {"access_token": token(uuid.uuid4(), role="platform_admin")},
    )  # at auth, but never linked here
    r = Client().post(reverse("platform:login"), FORM)
    assert r.status_code == 200 and "pas relié" in r.content.decode()
    dashboard["login"] = (
        200,
        {"access_token": token(uuid.uuid4(), role="customer", app="admin")},
    )  # a customer token is not an admin one
    assert Client().post(reverse("platform:login"), FORM).status_code == 200
    assert User.objects.filter(role="platform_admin").count() == 1


def test_a_dashboard_session_ends_when_the_auth_session_does(dashboard, monkeypatch):
    from platform_admin.mixins import PlatformAdminRequiredMixin

    c = signed_in()
    dashboard["alive"] = False
    assert (
        c.get(reverse("platform:retailer_list")).status_code == 200
    )  # checked at most once a minute: the sign-in counts as a check
    monkeypatch.setattr(PlatformAdminRequiredMixin, "CHECK_EVERY_SECONDS", -1)
    r = c.get(reverse("platform:retailer_list"))
    assert r.status_code == 302 and "login" in r["Location"]
    assert c.get(reverse("platform:retailer_list")).status_code == 302  # and she stays out
    dashboard["alive"] = None  # auth unreachable: fails closed, like a closed session
    c2 = signed_in()
    r2 = c2.get(reverse("platform:retailer_list"))
    assert r2.status_code == 302 and "login" in r2["Location"]
    dashboard["alive"] = True
    c3 = signed_in()
    assert (
        c3.get(reverse("platform:retailer_list")).status_code == 200
    )  # an answer of "alive" keeps her in


def test_a_new_retailer_enrols_its_first_staff_by_phone_with_no_email_and_no_password(dashboard):
    c = signed_in()
    page = c.get(reverse("platform:retailer_create")).content.decode()
    assert "staff_phone" in page and "staff_password" not in page and "staff_email" not in page
    sub = uuid.uuid4()
    dashboard["enrol"] = sub
    r = c.post(
        reverse("platform:retailer_create"),
        {"name": "Chez Awa", "staff_name": "Awa Kone", "staff_phone": "07 05 06 07 08"},
    )
    assert r.status_code == 302
    retailer = Retailer.objects.get(name="Chez Awa")
    staff = User.objects.get(auth_user_id=sub)
    assert (
        staff.role == "retailer_staff"
        and staff.retailer == retailer
        and staff.email is None
        and not staff.has_usable_password()
    )
    assert retailer.status == "pending"


def test_a_number_that_already_has_an_account_creates_nothing(dashboard):
    c = signed_in()
    dashboard["enrol"] = "phone_taken"
    r = c.post(
        reverse("platform:retailer_create"),
        {"name": "Chez Awa", "staff_name": "Awa", "staff_phone": "07 05 06 07 08"},
    )
    assert r.status_code == 200 and "déjà un compte" in r.content.decode()
    assert not Retailer.objects.filter(name="Chez Awa").exists()


def test_if_the_local_write_fails_the_person_is_taken_back_out_at_auth(dashboard, monkeypatch):
    c = signed_in()
    sub = uuid.uuid4()
    dashboard["enrol"] = sub

    def boom(self, *a, **k):
        raise RuntimeError("db down")

    monkeypatch.setattr(User, "save", boom)
    with pytest.raises(RuntimeError):
        c.post(
            reverse("platform:retailer_create"),
            {"name": "Chez Awa", "staff_name": "Awa", "staff_phone": "07 05 06 07 08"},
        )
    assert (
        dashboard["removed"] == [str(sub)] and not Retailer.objects.filter(name="Chez Awa").exists()
    )
