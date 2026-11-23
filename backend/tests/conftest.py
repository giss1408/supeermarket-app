import pytest
from django.core.cache import cache

# The platform kit (regisse_kit) lives in the private platform repo. Where it is not installed
# (a plain pip install of this backend), the SSO and observability tests cannot run: they are
# not collected, and the rest of the suite still does.
try:
    import regisse_kit  # noqa: F401
except ImportError:
    collect_ignore_glob = ["*test_sso_*.py", "test_observability.py"]


@pytest.fixture(autouse=True)
def _clear_cache():
    """Throttle counters live in the cache; never let them leak between tests."""
    cache.clear()
    yield
    cache.clear()


@pytest.fixture(autouse=True)
def _isolated_media(settings, tmp_path):
    """Uploads never touch backend/media/: every test gets its own MEDIA_ROOT."""
    settings.MEDIA_ROOT = tmp_path / "media"


@pytest.fixture
def sso_on(settings, monkeypatch):
    """SSO enabled with a local key: tokens from tests.sso_helpers are accepted, nothing leaves the
    process."""
    from regisse_kit.sso import SsoVerifier

    from accounts import sso
    from tests import sso_helpers

    settings.SSO_ENABLED = True
    settings.SSO_ISSUER = sso_helpers.ISS
    settings.SSO_JWKS_URL = "http://auth.test/.well-known/jwks.json"
    settings.SSO_AUTH_URL = "http://auth.test"
    settings.SSO_SERVICE_KEY = "svc-key"
    verifier = SsoVerifier(
        issuer=sso_helpers.ISS, audience="supermarket", jwks_fetch=sso_helpers.jwks
    )
    monkeypatch.setattr(sso, "verifier", lambda: verifier)
    return sso
