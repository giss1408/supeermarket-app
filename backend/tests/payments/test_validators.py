import pytest
from django.core.exceptions import ValidationError

from payments.validators import normalize_ci_phone, validate_ci_phone

GOOD = "+2250701020304"


@pytest.mark.parametrize(
    "raw",
    [
        "+2250701020304",
        "+225 07 01 02 03 04",
        "00225 0701020304",
        "07-01-02-03-04",
        "07.01.02.03.04",
        "0701020304",
        " 07 01-02.03 04 ",
    ],
)
def test_accepts(raw):
    assert normalize_ci_phone(raw) == GOOD


@pytest.mark.parametrize(
    "raw",
    [
        "0701020",
        "07010203",
        "+22507010203",
        "+2250701020304 5",
        "+33612345678",
        "0701O20304",
        "",
        "   ",
        "07010203045",
        "+225701020304",
        "abc",
    ],
)
def test_rejects(raw):
    with pytest.raises(ValidationError):
        normalize_ci_phone(raw)


def test_validate_accepts_only_normalised():
    validate_ci_phone(GOOD)
    for bad in ["0701020304", "+225 0701020304", "", "+22507010203"]:
        with pytest.raises(ValidationError):
            validate_ci_phone(bad)
