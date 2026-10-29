"""Each localised custom message, once in French and once in English, through the API."""

import pytest
from rest_framework.test import APIClient

from tests.factories import (
    PASSWORD,
    PaymentMethodFactory,
    ShoppingListFactory,
    StaffFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db

FR = {"headers": {"Accept-Language": "fr"}}
EN = {"headers": {"Accept-Language": "en"}}
STAFF = "/api/v1/staff/payment-methods"


def staff_client():
    c = APIClient()
    c.force_authenticate(StaffFactory())
    return c


def body(**extra):
    return {"provider": "wave", "phone_number": "0701020304", "current_password": PASSWORD, **extra}


def field_errors(res, field):
    assert res.status_code == 400
    assert res.json()["code"] == "validation_error"
    return res.json()["fields"][field]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [
        (FR, "Saisissez un numéro de téléphone ivoirien valide"),
        (EN, "Enter a valid Ivorian phone number"),
    ],
)
def test_invalid_phone(opts, expected):
    res = staff_client().post(STAFF, body(phone_number="12345"), format="json", **opts)
    assert field_errors(res, "phone_number")[0].startswith(expected)


@pytest.mark.parametrize(
    ("opts", "expected"),
    [(FR, "Votre mot de passe actuel est requis."), (EN, "Your current password is required.")],
)
def test_current_password_required(opts, expected):
    data = body()
    del data["current_password"]
    method = PaymentMethodFactory()
    res = staff_client().patch(f"{STAFF}/{method.pk}", data, format="json", **opts)
    assert field_errors(res, "current_password") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [(FR, "Mot de passe incorrect."), (EN, "Incorrect password.")],
)
def test_incorrect_password(opts, expected):
    res = staff_client().post(STAFF, body(current_password="wrong"), format="json", **opts)
    assert field_errors(res, "current_password") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [
        (FR, "Un moyen de paiement existe déjà pour ce fournisseur."),
        (EN, "A payment method for this provider already exists."),
    ],
)
def test_provider_exists(opts, expected):
    PaymentMethodFactory(provider="wave")
    res = staff_client().post(STAFF, body(), format="json", **opts)
    assert field_errors(res, "provider") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [
        (FR, "Le fournisseur d'un moyen de paiement ne peut pas être modifié."),
        (EN, "The provider of a payment method cannot change."),
    ],
)
def test_provider_immutable(opts, expected):
    method = PaymentMethodFactory(provider="wave")
    res = staff_client().patch(
        f"{STAFF}/{method.pk}",
        {"provider": "mtn_momo", "current_password": PASSWORD},
        format="json",
        **opts,
    )
    assert field_errors(res, "provider") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [
        (FR, "Un utilisateur avec cette adresse e-mail existe déjà."),
        (EN, "A user with this email already exists."),
    ],
)
def test_email_taken(opts, expected):
    UserFactory(email="taken@example.com")
    res = APIClient().post(
        "/api/v1/auth/register",
        {"email": "Taken@example.com", "password": PASSWORD, "name": "T"},
        format="json",
        **opts,
    )
    assert field_errors(res, "email") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [(FR, "Jeton invalide ou expiré."), (EN, "Invalid or expired token.")],
)
def test_invalid_logout_token(opts, expected):
    c = APIClient()
    c.force_authenticate(UserFactory())
    res = c.post("/api/v1/auth/logout", {"refresh": "garbage"}, format="json", **opts)
    assert field_errors(res, "refresh") == [expected]


@pytest.mark.parametrize(
    ("opts", "expected"),
    [(FR, "Un produit ou un texte est requis."), (EN, "Either product or text is required.")],
)
def test_item_needs_product_or_text(opts, expected):
    user = UserFactory()
    lst = ShoppingListFactory(user=user)
    c = APIClient()
    c.force_authenticate(user)
    res = c.post(f"/api/v1/lists/{lst.id}/items", {"text": ""}, format="json", **opts)
    assert field_errors(res, "non_field_errors") == [expected]
