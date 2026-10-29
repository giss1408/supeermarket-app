import re

from django.core.exceptions import ValidationError

from common.messages import msg_lazy

_SEPARATORS = re.compile(r"[ .\-]")
_NORMALISED = re.compile(r"\+225\d{10}")
_MESSAGE = msg_lazy("invalid_phone")


def normalize_ci_phone(raw: str) -> str:
    """Return ``+225`` + 10 digits, or raise ValidationError.

    Accepts ``+225`` + 10 digits, ``00225`` + 10 digits and the national 10-digit form
    starting with ``0``. Spaces, dots and dashes are ignored anywhere.
    """
    value = _SEPARATORS.sub("", raw or "")
    if value.startswith("+225"):
        digits = value[4:]
    elif value.startswith("00225"):
        digits = value[5:]
    elif value.startswith("0"):
        digits = value
    else:
        raise ValidationError(_MESSAGE, code="invalid_phone")
    # str.isdigit() accepts non-ASCII digits, so check explicitly.
    if len(digits) != 10 or not re.fullmatch(r"[0-9]{10}", digits):
        raise ValidationError(_MESSAGE, code="invalid_phone")
    return "+225" + digits


def validate_ci_phone(value: str) -> None:
    """Model/form validator: accepts only the already-normalised form."""
    if not _NORMALISED.fullmatch(value or "") or not value[1:].isascii():
        raise ValidationError(_MESSAGE, code="invalid_phone")
