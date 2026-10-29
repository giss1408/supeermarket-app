"""Shared helpers for all-or-nothing CSV imports (used by the admin)."""

import csv
import io
from collections.abc import Callable, Iterator
from typing import Any

from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Model


class CsvImportError(Exception):
    """Raised when any row is invalid; nothing has been imported."""

    def __init__(self, errors: list[str]):
        super().__init__("; ".join(errors))
        self.errors = errors


def iter_rows(text: str, columns: list[str]) -> Iterator[tuple[int, dict[str, str]]]:
    """Yield (row_number, row) where row 1 is the header and data starts at 2."""
    reader = csv.DictReader(io.StringIO(text.lstrip("﻿")))
    missing = [c for c in columns if c not in (reader.fieldnames or [])]
    if missing:
        raise CsvImportError([f"Missing columns: {', '.join(missing)}"])
    for number, row in enumerate(reader, start=2):
        yield number, {k: (v or "").strip() for k, v in row.items() if k is not None}


def import_rows[M: Model](
    text: str,
    columns: list[str],
    build: Callable[[dict[str, str]], M],
) -> int:
    """Build, validate and save one model per row, all in one transaction.

    `build` returns an unsaved instance (it may raise ValidationError/ValueError/
    LookupError). Every row is validated; any error aborts the whole import.
    """
    errors: list[str] = []
    instances: list[M] = []
    for number, row in iter_rows(text, columns):
        try:
            instance = build(row)
            instance.full_clean()
        except ValidationError as exc:
            errors.append(f"Row {number}: {_flatten(exc)}")
        except (ValueError, LookupError, ArithmeticError) as exc:
            errors.append(f"Row {number}: {exc}")
        else:
            instances.append(instance)
    if errors:
        raise CsvImportError(errors)
    with transaction.atomic():
        for instance in instances:
            instance.save()
    return len(instances)


def _flatten(exc: ValidationError) -> str:
    if hasattr(exc, "message_dict"):
        parts: Any = (f"{k}: {' '.join(v)}" for k, v in exc.message_dict.items())
        return "; ".join(parts)
    return " ".join(exc.messages)
