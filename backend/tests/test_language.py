import pytest
from rest_framework.test import APIClient

pytestmark = pytest.mark.django_db

REGISTER = "/api/v1/auth/register"
BODY = {"email": "new@example.com", "password": "123", "name": "N"}
FR_TOO_SHORT = "Ce mot de passe est trop court. Il doit contenir au minimum 8 caractères."
EN_TOO_SHORT = "This password is too short. It must contain at least 8 characters."


def register(**headers):
    return APIClient().post(REGISTER, BODY, format="json", **headers)


@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"headers": {"Accept-Language": "fr"}},
        {"headers": {"Accept-Language": "fr-CI"}},
        {"headers": {"Accept-Language": "fr-FR"}},
        {"headers": {"Accept-Language": "de"}},
    ],
)
def test_french_by_default_and_for_fr_or_unsupported(headers):
    res = register(**headers)
    assert res.status_code == 400
    body = res.json()
    assert body["code"] == "validation_error"
    assert FR_TOO_SHORT in body["fields"]["password"]


def test_english_is_honoured():
    res = register(headers={"Accept-Language": "en"})
    assert res.status_code == 400
    body = res.json()
    assert body["code"] == "validation_error"
    assert EN_TOO_SHORT in body["fields"]["password"]


def test_unknown_url_keeps_json_404_with_english_code():
    res = APIClient().get("/api/v1/nope")
    assert res.status_code == 404
    assert res.json()["code"] == "not_found"


def test_settings_defaults(settings):
    assert settings.LANGUAGE_CODE == "fr"
    assert [code for code, _ in settings.LANGUAGES] == ["fr", "en"]
    assert settings.CURRENCY == "XOF"
    assert settings.TIME_ZONE == "UTC"
    mw = settings.MIDDLEWARE
    assert (
        mw.index("django.contrib.sessions.middleware.SessionMiddleware")
        < mw.index("django.middleware.locale.LocaleMiddleware")
        < mw.index("django.middleware.common.CommonMiddleware")
    )
