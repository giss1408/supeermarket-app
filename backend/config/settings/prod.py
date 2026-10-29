from .base import *  # noqa: F403

DEBUG = False
SECRET_KEY = os.environ["SECRET_KEY"]  # noqa: F405  (required in production)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = os.environ.get("SECURE_SSL_REDIRECT", "1") == "1"  # noqa: F405
SECURE_REDIRECT_EXEMPT = [r"^healthz$"]

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
