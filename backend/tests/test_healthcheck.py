import pytest

from healthcheck import first_host


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("api.example.com", "api.example.com"),
        (".example.com,api.example.com", "example.com"),
        (" .example.com ", "example.com"),
        ("a.example.com, b.example.com", "a.example.com"),
        ("", "localhost"),
        (" , ", "localhost"),
        (".", "localhost"),
    ],
)
def test_first_host(raw, expected):
    assert first_host(raw) == expected
