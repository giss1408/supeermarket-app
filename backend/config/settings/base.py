import os
from datetime import timedelta
from pathlib import Path
from typing import Any

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Dev-only fallback; production settings reject it.
DEV_SECRET_KEY = "insecure-dev-only-key-change-me-0123456789abcdef"
SECRET_KEY = os.environ.get("SECRET_KEY", DEV_SECRET_KEY)
DEBUG = False
ALLOWED_HOSTS = [
    h.strip() for h in os.environ.get("ALLOWED_HOSTS", "localhost").split(",") if h.strip()
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    # `common` must precede drf_spectacular: its `spectacular` command shadows the library's.
    "common",
    "drf_spectacular",
    "accounts",
    "retailers",
    "platform_admin",
    "catalog",
    "offers",
    "stores",
    "shopping",
    "staff",
    "uploads",
    "payments",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
CSRF_FAILURE_VIEW = "common.handlers.csrf_failure"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

DATABASES = {
    "default": dj_database_url.config(
        env="DATABASE_URL",
        default="postgres://app:app@localhost:5434/app",
        conn_max_age=60,
    )
}

AUTH_USER_MODEL = "accounts.User"

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "fr"
LANGUAGES = [("fr", "Français"), ("en", "English")]
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

STORAGES: dict[str, dict[str, Any]] = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Platform SSO (the `auth` service). Off by default: the app's own tokens keep working either
# way. When on, API calls ALSO accept tokens
# issued by `auth` for audience "supermarket" (verified locally with its JWKS). Customers are
# opened from the token on first use; staff and
# platform admins must have been linked or enrolled before (never created from a token).
# LEGACY_AUTH_ENABLED=0 switches the app's own
# email register/login/refresh/logout endpoints off: people sign in at `auth` (phone + password,
# WhatsApp activation), like in flariane and fidelia.
SSO_ENABLED = os.environ.get("SSO_ENABLED") == "1"
SSO_ISSUER = os.environ.get("SSO_ISSUER", "")
SSO_JWKS_URL = os.environ.get("SSO_JWKS_URL", "")
SSO_AUDIENCE = os.environ.get("SSO_AUDIENCE", "supermarket")
SSO_AUTH_URL = os.environ.get("SSO_AUTH_URL", "").rstrip(
    "/"
)  # reachable from this container, e.g. http://auth-web:8000
SSO_SERVICE_KEY = os.environ.get("SSO_SERVICE_KEY", "")
SSO_MONEY_FAIL_CLOSED = os.environ.get("SSO_MONEY_FAIL_CLOSED", "1") == "1"
LEGACY_AUTH_ENABLED = os.environ.get("LEGACY_AUTH_ENABLED", "1") == "1"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["accounts.authentication.DualJWTAuthentication"],
    "EXCEPTION_HANDLER": "common.errors.custom_exception_handler",
    "DEFAULT_PAGINATION_CLASS": "common.pagination.DefaultCursorPagination",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_RATES": {
        "auth": os.environ.get("AUTH_THROTTLE_RATE", "10/min"),
        # Password step-up writes (payment methods): every attempt counts, per staff user.
        "staff_sensitive": os.environ.get("STAFF_SENSITIVE_THROTTLE_RATE", "5/min"),
    },
    # Reverse proxies in front of the app: 0 = none (REMOTE_ADDR is the client). With N > 0 the
    # throttle keys on the Nth-from-right X-Forwarded-For entry, which a client cannot spoof.
    "NUM_PROXIES": int(os.environ.get("NUM_PROXIES", "0")),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Supermarket API",
    "DESCRIPTION": (
        "REST API of the supermarket app. Authenticate with a JWT access token sent as "
        "'Authorization: Bearer <token>'. Every error response uses the standard shape "
        "{code, detail, fields}."
    ),
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
    "SCHEMA_PATH_PREFIX": r"/api/v1",
    "SORT_OPERATIONS": False,
    "POSTPROCESSING_HOOKS": [
        "drf_spectacular.hooks.postprocess_schema_enums",
        "common.openapi.add_error_responses",
        "common.openapi.sort_methods",
        "common.openapi.hide_form_content_types",
    ],
}

CURRENCY = os.environ.get("CURRENCY", "XOF")
