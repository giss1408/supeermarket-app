"""Tokens signed here with a throwaway Ed25519 key and a local JWKS: no network, no auth service."""

import base64
import time
import uuid

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

ISS = "http://auth.test"
KEY = Ed25519PrivateKey.generate()
OTHER_KEY = Ed25519PrivateKey.generate()


def jwks() -> dict:
    raw = KEY.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return {
        "keys": [
            {
                "kty": "OKP",
                "crv": "Ed25519",
                "alg": "EdDSA",
                "kid": "k1",
                "x": base64.urlsafe_b64encode(raw).rstrip(b"=").decode(),
            }
        ]
    }


def token(
    sub: str | uuid.UUID | None = None, *, key=KEY, alg="EdDSA", role="customer", app=None, **over
) -> str:
    now = int(time.time())
    app = app or {
        "customer": "customer",
        "retailer_staff": "retailer",
        "platform_admin": "admin",
    }.get(role, "customer")
    claims = {
        "iss": ISS,
        "aud": "supermarket",
        "sub": str(sub or uuid.uuid4()),
        "ph": "tel:+2250701020304",
        "role": role,
        "roles": [role],
        "app": app,
        "amr": ["pwd", "totp"] if role == "platform_admin" else ["pwd"],
        "auth_time": now,
        "iat": now,
        "exp": now + 600,
        "sid": "sid-12345678",
        **over,
    }
    claims = {k: v for k, v in claims.items() if v is not None}
    return jwt.encode(claims, key, algorithm=alg, headers={"kid": "k1"})


def bearer(t: str) -> dict:
    return {"HTTP_AUTHORIZATION": f"Bearer {t}"}
