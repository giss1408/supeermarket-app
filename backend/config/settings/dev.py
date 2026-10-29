from .base import *  # noqa: F403

DEBUG = True
ALLOWED_HOSTS = ["*"]
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.environ.get("EMAIL_HOST", "localhost")  # noqa: F405
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "1025"))  # noqa: F405
