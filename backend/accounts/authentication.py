"""API authentication: the app's own JWT (simplejwt) and, when SSO is on, tokens issued by the platform `auth` service.

Customers are opened from the token on first use (auth already proved the phone and recorded consent). Retailer staff and platform admins are
NEVER created from a token: they must have been enrolled by the platform (dashboard) or linked by `manage.py link_sso_user`, because their role
carries a retailer binding and power that only this product can grant."""

import uuid

from django.db import IntegrityError
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken

from . import sso
from .models import User

# the role in the token -> the auth "app" that issues it
ROLE_APP = {"customer": "customer", "retailer_staff": "retailer", "platform_admin": "admin"}


def user_for_principal(p: sso.SsoPrincipal) -> User:
    if ROLE_APP.get(p.role) != p.app:
        raise AuthenticationFailed("wrong_app")
    if p.must_change_password:
        raise AuthenticationFailed("password_change_required")
    if p.role == User.Role.PLATFORM_ADMIN and "totp" not in p.amr:
        raise AuthenticationFailed("authenticator_required")
    try:
        auth_id = uuid.UUID(p.sub)
    except ValueError:
        raise AuthenticationFailed("invalid_token") from None
    user = User.objects.filter(auth_user_id=auth_id).first()
    if user is None and p.legacy_id:  # a migrated account: auth says which row of this product it is
        try:
            user = User.objects.filter(pk=int(p.legacy_id), auth_user_id__isnull=True).first()
        except ValueError:
            user = None
        if user is not None:
            user.auth_user_id = auth_id
            user.save(update_fields=["auth_user_id"])
    if user is None:
        if p.role != User.Role.CUSTOMER:
            raise AuthenticationFailed("not_linked")
        try:
            user = User.objects.create_sso_customer(auth_id)
        except IntegrityError:  # two first requests at once: the other one created her
            user = User.objects.filter(auth_user_id=auth_id).first()
            if user is None:
                raise AuthenticationFailed("invalid_token") from None
    if not user.is_active:
        raise AuthenticationFailed("inactive")
    if user.role != p.role:
        raise AuthenticationFailed("role_mismatch")
    return user


class DualJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):  # type: ignore[no-untyped-def]
        header = self.get_header(request)
        if header is None:
            return None
        raw = self.get_raw_token(header)
        if raw is None:
            return None
        try:
            return super().authenticate(request)
        except (InvalidToken, AuthenticationFailed) as own_failure:
            principal = sso.verify(raw.decode()) if sso.enabled() else None
            if principal is None:
                raise own_failure from None
            return user_for_principal(principal), principal
