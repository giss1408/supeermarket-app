import sys

import dj_database_url
from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403


def _required(name: str) -> str:
    value = os.environ.get(name, "").strip()  # noqa: F405
    if not value:
        raise ImproperlyConfigured(f"The {name} environment variable is required in production.")
    return value


def _csv(name: str) -> list[str]:
    return [item.strip() for item in os.environ.get(name, "").split(",") if item.strip()]  # noqa: F405


# Everything security-relevant is read from the environment here; the development
# defaults in base.py (secret key, database URL, hosts) are never used in production.
DEBUG = False

SECRET_KEY = _required("SECRET_KEY")
if SECRET_KEY == DEV_SECRET_KEY:  # noqa: F405
    raise ImproperlyConfigured("SECRET_KEY must not be the insecure development default.")
if len(SECRET_KEY) < 32:
    raise ImproperlyConfigured("SECRET_KEY must be at least 32 characters long.")

DATABASES = {
    "default": dj_database_url.parse(_required("DATABASE_URL"), conn_max_age=60),
}

ALLOWED_HOSTS = _csv("ALLOWED_HOSTS")
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured(
        "The ALLOWED_HOSTS environment variable is required in production "
        "(comma-separated host names)."
    )
if "*" in ALLOWED_HOSTS:
    raise ImproperlyConfigured("ALLOWED_HOSTS must not contain the wildcard '*' in production.")
CSRF_TRUSTED_ORIGINS = _csv("CSRF_TRUSTED_ORIGINS")

# Cookies are Secure (https only) unless COOKIES_SECURE=0, which exists only for a staging stack served over plain http on a laptop.
_COOKIES_SECURE = os.environ.get("COOKIES_SECURE", "1") != "0"  # noqa: F405
SESSION_COOKIE_SECURE = _COOKIES_SECURE
CSRF_COOKIE_SECURE = _COOKIES_SECURE
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = os.environ.get("SECURE_SSL_REDIRECT", "1") == "1"  # noqa: F405
SECURE_REDIRECT_EXEMPT = [r"^healthz$", r"^readyz$", r"^metrics$"]  # /metrics is scraped over plain http inside the private network
SECURE_HSTS_SECONDS = int(os.environ.get("SECURE_HSTS_SECONDS", "31536000"))  # noqa: F405
SECURE_HSTS_INCLUDE_SUBDOMAINS = os.environ.get("SECURE_HSTS_INCLUDE_SUBDOMAINS") == "1"  # noqa: F405
SECURE_HSTS_PRELOAD = False
# Deliberate: subdomain HSTS and preload are opt-in (they affect every subdomain and are hard
# to undo), so the corresponding deploy-check warnings are acknowledged here.
SILENCED_SYSTEM_CHECKS = ["security.W005", "security.W021"]
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
SECURE_REFERRER_POLICY = "same-origin"

# Caddy is the single trusted proxy in front of gunicorn; without this every client would share
# the proxy's IP (and one auth throttle bucket). Set 0 if gunicorn is exposed directly.
REST_FRAMEWORK = {  # noqa: F405
    **REST_FRAMEWORK,  # noqa: F405
    "NUM_PROXIES": int(os.environ.get("NUM_PROXIES", "1")),  # noqa: F405
}

# Shared cache so the auth throttle limit holds across gunicorn workers. On the shared platform it is the product's Redis (REDIS_URL, an
# ACL user and a database index of its own); otherwise the database table (create it with `python manage.py createcachetable` after `migrate`).
if os.environ.get("REDIS_URL"):  # noqa: F405
    CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.redis.RedisCache",
            "LOCATION": os.environ["REDIS_URL"],  # noqa: F405
            "KEY_PREFIX": "supermarket",
        }
    }
else:
    CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.db.DatabaseCache",
            "LOCATION": "django_cache_table",
        }
    }

# Admin static files are served by WhiteNoise (collected at image build time).
MIDDLEWARE = [
    MIDDLEWARE[0],  # noqa: F405
    "whitenoise.middleware.WhiteNoiseMiddleware",
    *MIDDLEWARE[1:],  # noqa: F405
]
STORAGES["staticfiles"] = {  # noqa: F405
    "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
}

# Uploaded media: S3-compatible object storage when a bucket is configured,
# otherwise local files. Credentials come from AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY in the environment (boto3 default chain).
if os.environ.get("AWS_STORAGE_BUCKET_NAME"):  # noqa: F405
    STORAGES["default"] = {  # noqa: F405
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "bucket_name": os.environ["AWS_STORAGE_BUCKET_NAME"],  # noqa: F405
            "endpoint_url": os.environ.get("AWS_S3_ENDPOINT_URL") or None,  # noqa: F405
            "region_name": os.environ.get("AWS_S3_REGION_NAME") or None,  # noqa: F405
            "custom_domain": os.environ.get("AWS_S3_CUSTOM_DOMAIN") or None,  # noqa: F405
            "file_overwrite": False,
            "default_acl": None,
            "querystring_auth": False,
        },
    }

# Observability (shared platform kit; absent on the stand-alone VPS image, which then runs as before): request ids, metrics by route template,
# one access line per request WITHOUT the query string, a token-gated /metrics (config/urls.py), and masking of phone numbers and tokens in logs.
try:
    from regisse_kit.redact import RedactingFilter  # noqa: F401

    _KIT_OBSERVABILITY = True
except ImportError:  # pragma: no cover
    _KIT_OBSERVABILITY = False

OBSERVABILITY_SERVICE = "supermarket"
METRICS_TOKEN = os.environ.get("METRICS_TOKEN", "").strip()  # noqa: F405
if METRICS_TOKEN and len(METRICS_TOKEN) < 32:
    raise ImproperlyConfigured("METRICS_TOKEN must be at least 32 characters (or unset to disable /metrics).")
if _KIT_OBSERVABILITY:
    # Third: SecurityMiddleware stays first and WhiteNoise second (tests/test_prod_settings.py); static files are not metered.
    MIDDLEWARE = [*MIDDLEWARE[:2], "regisse_kit.django_observability.ObservabilityMiddleware", *MIDDLEWARE[2:]]

# Logs go to stdout/stderr only; the container runtime collects them.
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": ({"redact": {"()": "regisse_kit.redact.RedactingFilter"}} if _KIT_OBSERVABILITY else {}),
    "formatters": {
        "plain": {"format": "%(asctime)s %(levelname)s %(name)s %(message)s"},
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "stream": sys.stderr,
            "formatter": "plain",
            "filters": (["redact"] if _KIT_OBSERVABILITY else []),
        },
    },
    "root": {
        "handlers": ["console"],
        "level": os.environ.get("LOG_LEVEL", "INFO").upper(),  # noqa: F405
    },
}

# Error reporting only when a DSN is configured.
if os.environ.get("SENTRY_DSN"):  # noqa: F405
    import sentry_sdk

    sentry_sdk.init(
        dsn=os.environ["SENTRY_DSN"],  # noqa: F405
        send_default_pii=False,
        traces_sample_rate=float(os.environ.get("SENTRY_TRACES_SAMPLE_RATE", "0.0")),  # noqa: F405
        environment=os.environ.get("SENTRY_ENVIRONMENT", "production"),  # noqa: F405
    )
