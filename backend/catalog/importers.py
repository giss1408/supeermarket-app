"""CSV import for products.

Header columns: name,category_slug,unit,ean,description
(category_slug must match an existing Category; unit, ean and description may be empty).
"""

from common.csv_import import import_rows

from .models import Category, Product

COLUMNS = ["name", "category_slug", "unit", "ean", "description"]


def _build(row: dict[str, str], seen_eans: set[str]) -> Product:
    try:
        category = Category.objects.get(slug=row["category_slug"])
    except Category.DoesNotExist:
        raise LookupError(f"unknown category_slug '{row['category_slug']}'") from None
    if row["ean"]:
        if row["ean"] in seen_eans:
            raise ValueError(f"duplicate EAN '{row['ean']}' in file")
        seen_eans.add(row["ean"])
    return Product(
        name=row["name"],
        category=category,
        unit=row["unit"],
        ean=row["ean"] or None,
        description=row["description"],
    )


def import_products_csv(text: str) -> int:
    seen_eans: set[str] = set()
    return import_rows(text, COLUMNS, lambda row: _build(row, seen_eans))
