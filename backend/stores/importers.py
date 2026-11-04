"""CSV import for stores.

Header columns: retailer_slug,name,address,city,postcode,latitude,longitude,phone
(phone may be empty; latitude/longitude are decimal degrees).
"""

from decimal import Decimal, InvalidOperation

from common.csv_import import import_rows, retailer_by_slug

from .models import Store

COLUMNS = ["retailer_slug", "name", "address", "city", "postcode", "latitude", "longitude", "phone"]


def _decimal(row: dict[str, str], key: str) -> Decimal:
    try:
        return Decimal(row[key])
    except InvalidOperation:
        raise ValueError(f"{key}: '{row[key]}' is not a number") from None


def _build(row: dict[str, str]) -> Store:
    return Store(
        retailer=retailer_by_slug(row["retailer_slug"]),
        name=row["name"],
        address=row["address"],
        city=row["city"],
        postcode=row["postcode"],
        latitude=_decimal(row, "latitude"),
        longitude=_decimal(row, "longitude"),
        phone=row["phone"],
    )


def import_stores_csv(text: str) -> int:
    return import_rows(text, COLUMNS, _build)
