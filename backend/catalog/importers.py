"""CSV import for products.

Header columns: retailer_slug,name,category_slug,unit,ean,description
(category_slug must match an existing Category of that retailer; unit, ean and description
may be empty).
"""

from common.csv_import import import_rows, retailer_by_slug

from .models import Category, Product

COLUMNS = ["retailer_slug", "name", "category_slug", "unit", "ean", "description"]


def _build(row: dict[str, str], seen_eans: set[tuple[str, str]]) -> Product:
    retailer = retailer_by_slug(row["retailer_slug"])
    try:
        category = Category.objects.get(retailer=retailer, slug=row["category_slug"])
    except Category.DoesNotExist:
        raise LookupError(f"unknown category_slug '{row['category_slug']}'") from None
    if row["ean"]:
        key = (retailer.slug, row["ean"])
        if key in seen_eans:
            raise ValueError(f"duplicate EAN '{row['ean']}' in file")
        seen_eans.add(key)
    return Product(
        retailer=retailer,
        name=row["name"],
        category=category,
        unit=row["unit"],
        ean=row["ean"] or None,
        description=row["description"],
    )


def import_products_csv(text: str) -> int:
    seen_eans: set[tuple[str, str]] = set()
    return import_rows(text, COLUMNS, lambda row: _build(row, seen_eans))
