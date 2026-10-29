import pytest
from django.utils import translation

from common import messages
from common.messages import CATALOG, msg, msg_lazy


def test_msg_follows_active_language():
    with translation.override("fr"):
        assert msg("incorrect_password") == "Mot de passe incorrect."
    with translation.override("en"):
        assert msg("incorrect_password") == "Incorrect password."


@pytest.mark.parametrize("lang", ["fr-CI", "fr-FR"])
def test_regional_french_is_french(lang):
    with translation.override(lang):
        assert msg("incorrect_password") == "Mot de passe incorrect."


def test_other_languages_get_english():
    from unittest import mock

    with mock.patch.object(messages, "get_language", return_value="en-GB"):
        assert msg("incorrect_password") == "Incorrect password."
    with mock.patch.object(messages, "get_language", return_value="de"):
        assert msg("incorrect_password") == "Incorrect password."


@pytest.mark.parametrize("value", [None, ""])
def test_none_or_empty_language_is_french(value):
    from unittest import mock

    with mock.patch.object(messages, "get_language", return_value=value):
        assert msg("incorrect_password") == "Mot de passe incorrect."


@pytest.fixture
def limit_key(monkeypatch):
    monkeypatch.setitem(
        CATALOG, "limit", {"fr": "{limit} caractères maximum.", "en": "At most {limit} characters."}
    )


def test_formatting_placeholders(limit_key):
    with translation.override("fr"):
        assert msg("limit", limit=500) == "500 caractères maximum."
    with translation.override("en"):
        assert msg("limit", limit=500) == "At most 500 characters."


def test_missing_key_raises_clear_keyerror():
    with pytest.raises(KeyError, match="no_such_key"):
        msg("no_such_key")


def test_lazy_resolves_at_render_time():
    lazy = msg_lazy("incorrect_password")
    with translation.override("en"):
        assert str(lazy) == "Incorrect password."
    with translation.override("fr"):
        assert str(lazy) == "Mot de passe incorrect."


def test_lazy_accepts_format_arguments(limit_key):
    lazy = msg_lazy("limit", limit=3)
    with translation.override("fr"):
        assert str(lazy) == "3 caractères maximum."


def test_every_key_has_french_and_english_text():
    assert CATALOG
    for key, texts in CATALOG.items():
        assert set(texts) == {"fr", "en"}, key
        assert texts["fr"].strip() and texts["en"].strip(), key
        assert texts["fr"] != texts["en"], key
