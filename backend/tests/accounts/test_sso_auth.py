"""The API accepts tokens from the platform auth service next to its own; customers are opened on first use, staff are never created from a token."""

import uuid

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import LoyaltyCard, User
from tests.factories import PASSWORD, PlatformAdminFactory, RetailerFactory, StaffFactory, UserFactory
from tests.sso_helpers import OTHER_KEY, bearer, token

pytestmark = pytest.mark.django_db


def get(path: str, **headers):
    return APIClient().get(path, **headers)


def test_off_by_default_an_auth_token_is_refused():
    assert get("/api/v1/me", **bearer(token())).status_code == 401


def test_a_customer_is_opened_from_the_token_on_first_use_with_a_card_and_no_email(sso_on):
    sub = uuid.uuid4()
    r = get("/api/v1/me", **bearer(token(sub)))
    assert r.status_code == 200 and r.json()["role"] == "customer" and r.json()["email"] == ""  # the contract keeps a string
    user = User.objects.get(auth_user_id=sub)
    assert user.email is None and not user.has_usable_password() and LoyaltyCard.objects.filter(user=user).exists()
    assert get("/api/v1/me/card", **bearer(token(sub))).status_code == 200
    assert get("/api/v1/me", **bearer(token(sub))).status_code == 200
    assert User.objects.filter(auth_user_id=sub).count() == 1  # the second call finds her


def test_staff_and_platform_admins_are_never_created_from_a_token(sso_on):
    for role in ("retailer_staff", "platform_admin"):
        r = get("/api/v1/me", **bearer(token(role=role)))
        assert r.status_code == 401
    assert User.objects.count() == 0


def test_a_linked_retailer_staff_member_works_inside_her_own_retailer(sso_on):
    retailer = RetailerFactory()
    sub = uuid.uuid4()
    call_command("link_sso_user", auth_user_id=str(sub), role="retailer_staff", retailer=retailer.slug, name="Awa")
    r = get("/api/v1/staff/products", **bearer(token(sub, role="retailer_staff")))
    assert r.status_code == 200
    assert User.objects.get(auth_user_id=sub).retailer == retailer
    # a customer token for the same person is not a staff token
    assert get("/api/v1/staff/products", **bearer(token(sub, role="customer"))).status_code == 401


def test_link_sso_user_is_strict(sso_on):
    retailer = RetailerFactory()
    sub = str(uuid.uuid4())
    with pytest.raises(CommandError):
        call_command("link_sso_user", auth_user_id="nope", role="platform_admin")
    with pytest.raises(CommandError):
        call_command("link_sso_user", auth_user_id=sub, role="retailer_staff", retailer="no-such-shop")
    with pytest.raises(CommandError):
        call_command("link_sso_user", auth_user_id=sub, role="platform_admin", retailer=retailer.slug)
    call_command("link_sso_user", auth_user_id=sub, role="platform_admin", name="Boss")
    call_command("link_sso_user", auth_user_id=sub, role="platform_admin")  # idempotent
    with pytest.raises(CommandError):
        call_command("link_sso_user", auth_user_id=sub, role="retailer_staff", retailer=retailer.slug)  # never changes a role silently
    assert User.objects.get(auth_user_id=sub).role == "platform_admin"


def test_a_platform_admin_needs_the_authenticator_in_her_token(sso_on):
    sub = uuid.uuid4()
    call_command("link_sso_user", auth_user_id=str(sub), role="platform_admin")
    assert get("/api/v1/me", **bearer(token(sub, role="platform_admin"))).status_code == 200
    assert get("/api/v1/me", **bearer(token(sub, role="platform_admin", amr=["pwd"]))).status_code == 401


@pytest.mark.parametrize(
    "over",
    [
        {"role": "customer", "app": "admin"},  # a role used in the wrong app
        {"mcp": True},  # a forced password change is still pending
        {"aud": "flariane"},
        {"iss": "http://evil.test"},
        {"exp": 1},
        {"role": None},
    ],
)
def test_bad_or_wrongly_scoped_tokens_are_refused(sso_on, over):
    assert get("/api/v1/me", **bearer(token(**over))).status_code == 401


def test_forged_tokens_are_refused(sso_on):
    assert get("/api/v1/me", **bearer(token(key=OTHER_KEY))).status_code == 401  # signed with another key
    assert get("/api/v1/me", **bearer(token()[:-6] + "AAAAAA")).status_code == 401  # tampered
    import jwt

    none_token = jwt.encode({"sub": str(uuid.uuid4()), "role": "customer"}, key=None, algorithm="none")
    assert get("/api/v1/me", **bearer(none_token)).status_code == 401


def test_the_apps_own_tokens_keep_working_with_sso_on(sso_on):
    user = UserFactory()
    access = str(RefreshToken.for_user(user).access_token)
    assert get("/api/v1/me", **bearer(access)).json()["email"] == user.email
    bad = get("/api/v1/me", **bearer("not.a.token"))
    assert bad.status_code == 401


def test_a_switched_off_account_and_a_role_mismatch_are_refused(sso_on):
    sub = uuid.uuid4()
    call_command("link_sso_user", auth_user_id=str(sub), role="platform_admin")
    User.objects.filter(auth_user_id=sub).update(is_active=False)
    assert get("/api/v1/me", **bearer(token(sub, role="platform_admin"))).status_code == 401
    cust = UserFactory(auth_user_id=uuid.uuid4())
    assert get("/api/v1/me", **bearer(token(cust.auth_user_id, role="retailer_staff"))).status_code == 401  # local role is customer


def test_a_migrated_row_is_found_by_the_lid_claim_and_linked(sso_on):
    user = UserFactory()
    sub = uuid.uuid4()
    assert get("/api/v1/me", **bearer(token(sub, lid=str(user.pk)))).status_code == 200
    user.refresh_from_db()
    assert user.auth_user_id == sub
    assert User.objects.count() == 1  # not a second customer


def test_the_legacy_email_endpoints_still_exist_by_default():
    assert APIClient().post("/api/v1/auth/login", {"email": "x@y.fr", "password": PASSWORD}, format="json").status_code in (400, 401)
