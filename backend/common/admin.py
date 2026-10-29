from collections.abc import Callable
from typing import Any

from django.contrib import admin, messages
from django.http import HttpRequest, HttpResponse, HttpResponseRedirect
from django.template.response import TemplateResponse
from django.urls import path, reverse

from .csv_import import CsvImportError


class CsvImportAdminMixin:
    """Adds an `import-csv/` admin view to a ModelAdmin.

    Subclasses set `csv_importer` (text -> row count) and `csv_columns` (help text).
    """

    csv_importer: Callable[[str], int]
    csv_columns: str = ""

    def get_urls(self):
        urls = super().get_urls()  # type: ignore[misc]
        custom = [
            path(
                "import-csv/",
                self.admin_site.admin_view(self.import_csv_view),  # type: ignore[attr-defined]
                name=self._csv_url_name(),
            )
        ]
        return custom + urls

    def _csv_url_name(self) -> str:
        meta = self.model._meta  # type: ignore[attr-defined]
        return f"{meta.app_label}_{meta.model_name}_import_csv"

    def changelist_view(self, request: HttpRequest, extra_context: dict[str, Any] | None = None):
        extra = {
            **(extra_context or {}),
            "import_csv_url": reverse(f"admin:{self._csv_url_name()}"),
        }
        return super().changelist_view(request, extra)  # type: ignore[misc]

    def import_csv_view(self, request: HttpRequest) -> HttpResponse:
        if not self.has_add_permission(request):  # type: ignore[attr-defined]
            from django.core.exceptions import PermissionDenied

            raise PermissionDenied
        errors: list[str] = []
        if request.method == "POST" and request.FILES.get("file"):
            upload = request.FILES["file"]
            try:
                text = upload.read().decode("utf-8-sig")  # type: ignore[union-attr]
                count = type(self).csv_importer(text)
            except UnicodeDecodeError:
                errors = ["File is not valid UTF-8."]
            except CsvImportError as exc:
                errors = exc.errors
            else:
                self.message_user(request, f"Imported {count} rows.", messages.SUCCESS)  # type: ignore[attr-defined]
                return HttpResponseRedirect("../")
        context = {
            **self.admin_site.each_context(request),  # type: ignore[attr-defined]
            "title": "Import CSV",
            "columns": self.csv_columns,
            "errors": errors,
            "opts": self.model._meta,  # type: ignore[attr-defined]
        }
        return TemplateResponse(request, "admin/csv_import.html", context)


__all__ = ["CsvImportAdminMixin", "admin"]
