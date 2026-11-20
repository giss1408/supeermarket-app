"""The product's side of the platform `auth` service: verify its tokens locally, and the few calls this product makes back (service key).

Never raises on a bad token; never logs a token, a phone number or a service key."""

import logging
import uuid
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any

import httpx
from django.conf import settings

try:
    from regisse_kit.sso import Principal, SsoError, SsoVerifier

    KIT = True
except ImportError:  # the stand-alone image (plain Dockerfile) has no platform kit: SSO is simply unavailable there
    KIT = False

    class SsoError(Exception):  # type: ignore[no-redef]
        pass

    @dataclass
    class Principal:  # type: ignore[no-redef]
        pass

log = logging.getLogger("supermarket.sso")


@dataclass
class SsoPrincipal(Principal):
    """The verified claims plus the raw token (kept for the live session check; never printed)."""

    token: str = field(default="", repr=False)


def enabled() -> bool:
    return bool(KIT and settings.SSO_ENABLED and settings.SSO_ISSUER and settings.SSO_JWKS_URL)


@lru_cache
def verifier() -> SsoVerifier:
    url = settings.SSO_JWKS_URL
    return SsoVerifier(
        issuer=settings.SSO_ISSUER,
        audience=settings.SSO_AUDIENCE,
        jwks_fetch=lambda: httpx.get(url, timeout=5).raise_for_status().json(),
    )


def reset() -> None:
    verifier.cache_clear()


def verify(token: str) -> SsoPrincipal | None:
    """The principal behind an `auth` token, or None when it is not acceptable (or SSO is off)."""
    if not enabled():
        return None
    try:
        p = verifier().verify(token)
    except (SsoError, httpx.HTTPError, ValueError):
        return None
    return SsoPrincipal(**vars(p), token=token)


def _service(path: str, *, method: str = "POST", json: dict[str, Any] | None = None, timeout: float = 5) -> httpx.Response:
    url = f"{settings.SSO_AUTH_URL}{path}"
    return httpx.request(method, url, json=json, headers={"X-Service-Key": settings.SSO_SERVICE_KEY}, timeout=timeout)


def configured_for_calls() -> bool:
    return bool(settings.SSO_AUTH_URL and settings.SSO_SERVICE_KEY)


def session_alive(token: str) -> bool | None:
    """Live check for sensitive writes (is the session alive, the user still active?). None = auth unreachable or not configured."""
    if not configured_for_calls():
        return None
    try:
        r = _service("/v1/introspect", json={"token": token}, timeout=3)
        r.raise_for_status()
        return bool(r.json().get("active"))
    except (httpx.HTTPError, ValueError):
        return None


def sid_alive(sid: str) -> bool | None:
    """Is the auth session `sid` still alive (the platform dashboard keeps its own Django session next to an auth login)?"""
    if not configured_for_calls():
        return None
    try:
        r = _service("/v1/sessions/check", json={"sid": sid}, timeout=3)
        r.raise_for_status()
        return bool(r.json().get("active"))
    except (httpx.HTTPError, ValueError):
        return None


def erase_identity(auth_user_id: uuid.UUID) -> bool | None:
    """Tell auth this product erased the person. None = not configured, True = auth answered, False = unreachable (retry later)."""
    if not (enabled() and configured_for_calls()):
        return None
    try:
        r = _service("/v1/service/erase", json={"user_id": str(auth_user_id)})
        r.raise_for_status()
        log.info("auth erase: %s", r.json().get("result"))
        return True
    except (httpx.HTTPError, ValueError):
        log.error("auth erase FAILED: the person is deleted here but her auth identity remains (queued for retry)")
        return False


class EnrolError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def enrol_staff(phone: str, name: str, role: str = "retailer_staff") -> str:
    """Enrols one of this product's staff at auth (pending account, WhatsApp activation by the team). Returns the auth user id.
    A number that already has an account is refused: this product has one role per person."""
    if not configured_for_calls():
        raise EnrolError("sso_not_configured")
    try:
        r = _service("/v1/service/staff", json={"phone": phone, "display_name": name, "role": role, "allow_existing": False}, timeout=10)
    except httpx.HTTPError:
        raise EnrolError("auth_unavailable") from None
    body: dict[str, Any] = {}
    try:
        body = r.json()
    except ValueError:
        pass
    if r.status_code == 201:
        return str(body["user_id"])
    raise EnrolError(str(body.get("detail", "enrol_failed")))


def remove_staff(auth_user_id: uuid.UUID | str) -> bool:
    """Best effort (compensation, or a staff member removed): takes the role away at auth."""
    try:
        return _service(f"/v1/service/staff/{auth_user_id}", method="DELETE").status_code == 200
    except httpx.HTTPError:
        return False


def login_at_auth(phone: str, password: str, totp: str) -> tuple[int, dict[str, Any]]:
    """The platform dashboard signs a platform admin in AT auth (phone + password + authenticator code); returns (status, body)."""
    try:
        r = httpx.post(
            f"{settings.SSO_AUTH_URL}/v1/login",
            json={"phone": phone, "password": password, "product": settings.SSO_AUDIENCE, "app": "admin", **({"totp": totp} if totp else {})},
            timeout=10,
        )
        return r.status_code, r.json()
    except (httpx.HTTPError, ValueError):
        return 503, {"detail": "auth_unavailable"}
