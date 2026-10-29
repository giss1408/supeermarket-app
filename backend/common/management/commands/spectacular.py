"""``manage.py spectacular`` that always renders the schema in English.

The committed openapi.yaml must not change with LANGUAGE_CODE. ``common`` precedes
drf_spectacular in INSTALLED_APPS, so this command shadows the library's (same name).
"""

from typing import Any

from django.utils import translation
from drf_spectacular.management.commands.spectacular import Command as SpectacularCommand


class Command(SpectacularCommand):
    def handle(self, *args: Any, **options: Any) -> None:
        with translation.override("en"):
            super().handle(*args, **options)
