"""Production settings, loaded in a clean subprocess so nothing leaks into other tests."""

import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parent.parent
GOOD_KEY = "k8Jx2mQp9vLw4Zt7Rb3NcYh6Ud1Fs5GaE0oIeWnVxTzBqM8yPj"
BASE_ENV = {
    "SECRET_KEY": GOOD_KEY,
    "DATABASE_URL": "postgres://u:p@db.example.com:5432/prod",
    "ALLOWED_HOSTS": "api.example.com",
    "DJANGO_SETTINGS_MODULE": "config.settings.prod",
}


def run_py(code: str, env: dict[str, str | None] | None = None) -> subprocess.CompletedProcess[str]:
    """Run `code` with a clean environment: only PATH plus BASE_ENV overridden by `env`."""
    full: dict[str, str] = {"PATH": os.environ.get("PATH", ""), **BASE_ENV}
    for key, value in (env or {}).items():
        if value is None:
            full.pop(key, None)
        else:
            full[key] = value
    return subprocess.run(
        [sys.executable, "-c", textwrap.dedent(code)],
        cwd=BACKEND_DIR,
        env=full,
        capture_output=True,
        text=True,
        timeout=120,
    )


def load(names: list[str], env: dict[str, str | None] | None = None) -> dict[str, Any]:
    code = f"""
        import json
        from config.settings import prod
        print(json.dumps({{n: getattr(prod, n) for n in {names!r}}}, default=str))
    """
    result = run_py(code, env)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout.strip().splitlines()[-1])


def assert_improperly_configured(env: dict[str, str | None], variable: str) -> None:
    result = run_py("from config.settings import prod", env)
    assert result.returncode != 0
    assert "ImproperlyConfigured" in result.stderr
    assert "KeyError" not in result.stderr
    assert variable in result.stderr


def test_prod_settings_require_secret_key_and_database_url() -> None:
    assert_improperly_configured({"SECRET_KEY": None}, "SECRET_KEY")
    assert_improperly_configured({"DATABASE_URL": None}, "DATABASE_URL")


def test_prod_rejects_insecure_or_short_secret_key() -> None:
    dev_default = "insecure-dev-only-key-change-me-0123456789abcdef"
    assert_improperly_configured({"SECRET_KEY": dev_default}, "SECRET_KEY")
    assert_improperly_configured({"SECRET_KEY": "short-key"}, "SECRET_KEY")
    assert_improperly_configured({"SECRET_KEY": "x" * 31}, "SECRET_KEY")


def test_prod_requires_allowed_hosts_and_rejects_wildcard() -> None:
    assert_improperly_configured({"ALLOWED_HOSTS": None}, "ALLOWED_HOSTS")
    assert_improperly_configured({"ALLOWED_HOSTS": " , "}, "ALLOWED_HOSTS")
    assert_improperly_configured({"ALLOWED_HOSTS": "api.example.com,*"}, "ALLOWED_HOSTS")
    values = load(["ALLOWED_HOSTS"], {"ALLOWED_HOSTS": "a.example.com, b.example.com"})
    assert values["ALLOWED_HOSTS"] == ["a.example.com", "b.example.com"]


def test_prod_csrf_trusted_origins_from_env() -> None:
    assert load(["CSRF_TRUSTED_ORIGINS"])["CSRF_TRUSTED_ORIGINS"] == []
    origins = "https://a.example.com, https://b.example.com"
    values = load(["CSRF_TRUSTED_ORIGINS"], {"CSRF_TRUSTED_ORIGINS": origins})
    assert values["CSRF_TRUSTED_ORIGINS"] == ["https://a.example.com", "https://b.example.com"]


def test_prod_debug_false_and_secure_cookies() -> None:
    names = [
        "DEBUG",
        "SESSION_COOKIE_SECURE",
        "CSRF_COOKIE_SECURE",
        "SECURE_SSL_REDIRECT",
        "SECURE_HSTS_SECONDS",
        "SECURE_HSTS_INCLUDE_SUBDOMAINS",
        "SECURE_HSTS_PRELOAD",
        "SECURE_CONTENT_TYPE_NOSNIFF",
        "X_FRAME_OPTIONS",
        "SECURE_REFERRER_POLICY",
    ]
    v = load(names)
    assert v["DEBUG"] is False
    assert v["SESSION_COOKIE_SECURE"] is True
    assert v["CSRF_COOKIE_SECURE"] is True
    assert v["SECURE_SSL_REDIRECT"] is True
    assert v["SECURE_HSTS_SECONDS"] == 31536000
    assert v["SECURE_HSTS_INCLUDE_SUBDOMAINS"] is False
    assert v["SECURE_HSTS_PRELOAD"] is False
    assert v["SECURE_CONTENT_TYPE_NOSNIFF"] is True
    assert v["X_FRAME_OPTIONS"] == "DENY"
    assert v["SECURE_REFERRER_POLICY"] == "same-origin"
    tuned = load(
        names,
        {"SECURE_HSTS_SECONDS": "60", "SECURE_HSTS_INCLUDE_SUBDOMAINS": "1"},
    )
    assert tuned["SECURE_HSTS_SECONDS"] == 60
    assert tuned["SECURE_HSTS_INCLUDE_SUBDOMAINS"] is True


def test_prod_does_not_use_dev_database_default() -> None:
    db = load(["DATABASES"])["DATABASES"]["default"]
    assert db["HOST"] == "db.example.com"
    assert db["NAME"] == "prod"
    assert db["USER"] == "u"
    assert db["PORT"] in (5432, "5432")


def test_prod_default_cache_is_database_cache() -> None:
    cache = load(["CACHES"])["CACHES"]["default"]
    assert cache["BACKEND"] == "django.core.cache.backends.db.DatabaseCache"
    assert cache["LOCATION"] == "django_cache_table"


def test_prod_s3_storage_when_bucket_configured() -> None:
    env: dict[str, str | None] = {
        "AWS_STORAGE_BUCKET_NAME": "my-bucket",
        "AWS_S3_ENDPOINT_URL": "https://s3.example.com",
        "AWS_S3_REGION_NAME": "eu-west-3",
        "AWS_S3_CUSTOM_DOMAIN": "cdn.example.com",
    }
    default = load(["STORAGES"], env)["STORAGES"]["default"]
    assert default["BACKEND"] == "storages.backends.s3.S3Storage"
    assert default["OPTIONS"] == {
        "bucket_name": "my-bucket",
        "endpoint_url": "https://s3.example.com",
        "region_name": "eu-west-3",
        "custom_domain": "cdn.example.com",
        "file_overwrite": False,
        "default_acl": None,
        "querystring_auth": False,
    }


def test_prod_filesystem_storage_without_bucket() -> None:
    default = load(["STORAGES"])["STORAGES"]["default"]
    assert default["BACKEND"] == "django.core.files.storage.FileSystemStorage"


def test_prod_staticfiles_use_whitenoise_manifest_storage_and_middleware_order() -> None:
    v = load(["STORAGES", "MIDDLEWARE", "STATIC_ROOT"])
    assert (
        v["STORAGES"]["staticfiles"]["BACKEND"]
        == "whitenoise.storage.CompressedManifestStaticFilesStorage"
    )
    middleware = v["MIDDLEWARE"]
    assert middleware[0] == "django.middleware.security.SecurityMiddleware"
    assert middleware[1] == "whitenoise.middleware.WhiteNoiseMiddleware"
    assert v["STATIC_ROOT"].endswith("staticfiles")


def test_dev_settings_unaffected_by_whitenoise() -> None:
    result = run_py(
        """
        from config.settings import dev
        assert "whitenoise.middleware.WhiteNoiseMiddleware" not in dev.MIDDLEWARE
        assert not hasattr(dev, "CACHES")  # Django default LocMemCache
        assert dev.STORAGES["staticfiles"]["BACKEND"].endswith("StaticFilesStorage")
        """,
        {"DJANGO_SETTINGS_MODULE": "config.settings.dev"},
    )
    assert result.returncode == 0, result.stderr


SENTRY_PROBE = """
    import json
    import sentry_sdk
    calls = []
    sentry_sdk.init = lambda **kw: calls.append(kw)
    from config.settings import prod  # noqa: F401
    print(json.dumps(calls, default=str))
"""


def test_prod_sentry_not_initialized_without_dsn() -> None:
    result = run_py(SENTRY_PROBE, {"SENTRY_DSN": None})
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout.strip().splitlines()[-1]) == []


def test_prod_sentry_initialized_with_dsn() -> None:
    dsn = "https://public@o0.ingest.sentry.io/1"
    result = run_py(SENTRY_PROBE, {"SENTRY_DSN": dsn})
    assert result.returncode == 0, result.stderr
    calls = json.loads(result.stdout.strip().splitlines()[-1])
    assert len(calls) == 1
    assert calls[0]["dsn"] == dsn
    assert calls[0]["send_default_pii"] is False
    assert calls[0]["traces_sample_rate"] == 0.0
    assert calls[0]["environment"] == "production"
    tuned = run_py(
        SENTRY_PROBE,
        {"SENTRY_DSN": dsn, "SENTRY_TRACES_SAMPLE_RATE": "0.25", "SENTRY_ENVIRONMENT": "staging"},
    )
    call = json.loads(tuned.stdout.strip().splitlines()[-1])[0]
    assert call["traces_sample_rate"] == 0.25
    assert call["environment"] == "staging"


def test_prod_logging_is_console_only() -> None:
    logging_cfg = load(["LOGGING"], {"LOG_LEVEL": "WARNING"})["LOGGING"]
    assert all(h["class"] == "logging.StreamHandler" for h in logging_cfg["handlers"].values())
    assert logging_cfg["root"]["level"] == "WARNING"
    assert load(["LOGGING"])["LOGGING"]["root"]["level"] == "INFO"


HEALTHZ_PROBE = """
    import json
    import django
    django.setup()
    from django.test import Client
    c = Client()
    https = c.get("/healthz", secure=True, headers={"host": "api.example.com"})
    plain = c.get("/healthz", headers={"host": "api.example.com"})
    other = c.get("/api/schema/", headers={"host": "api.example.com"})
    print(json.dumps({
        "https": https.status_code,
        "plain": plain.status_code,
        "other": other.status_code,
        "location": other["Location"] if other.status_code in (301, 302) else None,
    }))
"""


def test_healthz_works_with_prod_settings() -> None:
    result = run_py(HEALTHZ_PROBE)
    assert result.returncode == 0, result.stderr
    out = json.loads(result.stdout.strip().splitlines()[-1])
    assert out["https"] == 200
    assert out["plain"] == 200
    assert out["other"] in (301, 302)
    assert out["location"].startswith("https://api.example.com/")


def test_check_deploy_passes_with_prod_settings() -> None:
    full = {"PATH": os.environ.get("PATH", ""), **BASE_ENV}
    result = subprocess.run(
        [sys.executable, "manage.py", "check", "--deploy", "--fail-level", "WARNING"],
        cwd=BACKEND_DIR,
        env=full,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert result.returncode == 0, result.stdout + result.stderr
