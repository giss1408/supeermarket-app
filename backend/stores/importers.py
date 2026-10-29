"""CSV import for stores.

Header columns: name,address,city,postcode,latitude,longitude,phone
(phone may be empty; latitude/longitude are decimal degrees).
"""

from decimal import Decimal, InvalidOperation

from common.csv_import import import_rows

from .models import Store

COLUMNS = ["name", "address", "city", "postcode", "latitude", "longitude", "phone"]


def _decimal(row: dict[str, str], key: str) -> Decimal:
    try:
        return Decimal(row[key])
    except InvalidOperation:
        raise ValueError(f"{key}: '{row[key]}' is not a number") from None


def _build(row: dict[str, str]) -> Store:
    return Store(
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
