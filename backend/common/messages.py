"""Plain-dict catalog of the custom user-facing validation messages (French and English).

Django's and DRF's built-in messages are translated by Django itself; only the messages this
project writes live here. ``msg`` picks the text for the active language (anything that does not
start with ``fr`` gets English; no or unknown language gets French, the project default).
"""

from typing import Any

from django.utils.functional import lazy
from django.utils.translation import get_language

CATALOG: dict[str, dict[str, str]] = {
    "invalid_phone": {
        "fr": (
            "Saisissez un numéro de téléphone ivoirien valide : 10 chiffres, "
            "par ex. 07 01 02 03 04 ou +225 07 01 02 03 04."
        ),
        "en": (
            "Enter a valid Ivorian phone number: 10 digits, "
            "e.g. 07 01 02 03 04 or +225 07 01 02 03 04."
        ),
    },
    "current_password_required": {
        "fr": "Votre mot de passe actuel est requis.",
        "en": "Your current password is required.",
    },
    "incorrect_password": {
        "fr": "Mot de passe incorrect.",
        "en": "Incorrect password.",
    },
    "provider_exists": {
        "fr": "Un moyen de paiement existe déjà pour ce fournisseur.",
        "en": "A payment method for this provider already exists.",
    },
    "provider_immutable": {
        "fr": "Le fournisseur d'un moyen de paiement ne peut pas être modifié.",
        "en": "The provider of a payment method cannot change.",
    },
    "email_taken": {
        "fr": "Un utilisateur avec cette adresse e-mail existe déjà.",
        "en": "A user with this email already exists.",
    },
    "invalid_token": {
        "fr": "Jeton invalide ou expiré.",
        "en": "Invalid or expired token.",
    },
    "item_needs_product_or_text": {
        "fr": "Un produit ou un texte est requis.",
        "en": "Either product or text is required.",
    },
}


def msg(key: str, **fmt: Any) -> str:
    """The message ``key`` in the active language, with ``fmt`` applied via ``str.format``."""
    try:
        texts = CATALOG[key]
    except KeyError:
        raise KeyError(f"Unknown message key: {key!r}") from None
    language = get_language() or "fr"
    text = texts["en"] if not language.lower().startswith("fr") else texts["fr"]
    return text.format(**fmt) if fmt else text


# For messages defined at import time (class attributes, module constants, validators).
msg_lazy = lazy(msg, str)
