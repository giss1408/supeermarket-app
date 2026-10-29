from django.contrib import admin

from common.admin import CsvImportAdminMixin

from .importers import COLUMNS, import_products_csv
from .models import Category, Product


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "sort_order"]
    search_fields = ["name", "slug"]
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Product)
class ProductAdmin(CsvImportAdminMixin, admin.ModelAdmin):
    """Import CSV header: name,category_slug,unit,ean,description."""

    list_display = ["name", "category", "unit", "ean"]
    list_filter = ["category"]
    search_fields = ["name", "ean"]
    csv_columns = ",".join(COLUMNS)
    change_list_template = "admin/csv_change_list.html"

    @staticmethod
    def csv_importer(text: str) -> int:  # type: ignore[override]
        return import_products_csv(text)
