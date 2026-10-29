from django.contrib import admin

from common.admin import CsvImportAdminMixin

from .importers import COLUMNS, import_stores_csv
from .models import OpeningHours, Store


class OpeningHoursInline(admin.TabularInline):
    model = OpeningHours
    extra = 0


@admin.register(Store)
class StoreAdmin(CsvImportAdminMixin, admin.ModelAdmin):
    """Import CSV header: name,address,city,postcode,latitude,longitude,phone."""

    list_display = ["name", "city", "postcode", "is_active"]
    list_filter = ["is_active", "city"]
    search_fields = ["name", "city", "postcode", "address"]
    inlines = [OpeningHoursInline]
    csv_columns = ",".join(COLUMNS)
    change_list_template = "admin/csv_change_list.html"

    @staticmethod
    def csv_importer(text: str) -> int:  # type: ignore[override]
        return import_stores_csv(text)


@admin.register(OpeningHours)
class OpeningHoursAdmin(admin.ModelAdmin):
    list_display = ["store", "weekday", "opens", "closes"]
    list_filter = ["weekday"]
    search_fields = ["store__name"]
