import uuid

from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from django.utils.text import slugify

from rest_framework.exceptions import AuthenticationFailed

from accounts import sso
from accounts.authentication import user_for_principal
from accounts.models import User
from payments.models import PaymentMethod
from retailers.errors import DuplicatePayment
from retailers.models import Retailer
from retailers.services import record_payment


class PlatformLoginForm(AuthenticationForm):
    def confirm_login_allowed(self, user):  # type: ignore[no-untyped-def]
        super().confirm_login_allowed(user)
        if user.role != User.Role.PLATFORM_ADMIN:
            raise forms.ValidationError(
                "Accès réservé aux administrateurs de la plateforme.", code="not_platform_admin"
            )


class PlatformSsoLoginForm(forms.Form):
    """The dashboard signs a platform admin in AT the auth service (phone + password + authenticator code), then opens a Django session for her
    linked profile. No password is kept here."""

    phone = forms.CharField(label="Numéro de téléphone", max_length=32)
    password = forms.CharField(label="Mot de passe", strip=False, widget=forms.PasswordInput(render_value=False))
    totp = forms.CharField(label="Code d'authentification", max_length=6, min_length=6)

    MESSAGES = {
        "invalid_credentials": "Numéro ou mot de passe incorrect.",
        "invalid_totp": "Code d'authentification incorrect ou déjà utilisé.",
        "totp_not_set_up": "Ce compte n'a pas encore d'application d'authentification.",
        "no_access_to_app": "Accès réservé aux administrateurs de la plateforme.",
        "account_blocked": "Ce compte est suspendu.",
        "not_activated": "Ce compte n'est pas encore activé.",
        "login_locked": "Trop d'essais. Réessayez dans 15 minutes.",
        "rate_limited": "Trop de tentatives. Réessayez dans quelques minutes.",
        "auth_unavailable": "Le service de connexion est momentanément indisponible.",
    }

    def __init__(self, *args, request=None, **kwargs):  # type: ignore[no-untyped-def]
        super().__init__(*args, **kwargs)
        self.request = request
        self._user: User | None = None
        self.sid = ""

    def clean(self):  # type: ignore[no-untyped-def]
        cleaned = super().clean()
        if self.errors:
            return cleaned
        status, body = sso.login_at_auth(cleaned["phone"].replace(" ", ""), cleaned["password"], cleaned["totp"])
        token = body.get("access_token") if status == 200 else None
        principal = sso.verify(token) if token else None
        if principal is None:
            raise forms.ValidationError(self.MESSAGES.get(str(body.get("detail")), "Connexion impossible."), code="sso_login_failed")
        try:
            user = user_for_principal(principal)
        except AuthenticationFailed:
            raise forms.ValidationError("Ce compte n'est pas relié à la plateforme.", code="not_linked") from None
        if user.role != User.Role.PLATFORM_ADMIN:
            raise forms.ValidationError("Accès réservé aux administrateurs de la plateforme.", code="not_platform_admin")
        user.backend = "django.contrib.auth.backends.ModelBackend"
        self._user, self.sid = user, principal.sid
        return cleaned

    def get_user(self) -> User | None:
        return self._user


class RetailerCreateSsoForm(forms.Form):
    """New retailer + its first staff member, enrolled at the auth service by phone: the team sends her a WhatsApp code and she chooses her own
    password (like a fidelia merchant). No e-mail, no password is typed here."""

    name = forms.CharField(label="Nom du commerçant", max_length=150)
    staff_name = forms.CharField(label="Nom du premier utilisateur", max_length=150)
    staff_phone = forms.CharField(label="Téléphone du premier utilisateur (WhatsApp)", max_length=32)

    ENROL_ERRORS = {
        "phone_taken": "Ce numéro a déjà un compte : utilisez un autre numéro.",
        "invalid_phone": "Numéro ivoirien à 10 chiffres attendu.",
        "auth_unavailable": "Le service de connexion est momentanément indisponible. Réessayez.",
        "sso_not_configured": "Le service de connexion n'est pas configuré.",
    }

    def save(self) -> Retailer:
        data = self.cleaned_data
        try:
            auth_user_id = sso.enrol_staff(data["staff_phone"].replace(" ", ""), data["staff_name"])
        except sso.EnrolError as exc:
            raise forms.ValidationError(self.ENROL_ERRORS.get(exc.code, "Création impossible."), code=exc.code) from None
        try:
            with transaction.atomic():
                retailer = Retailer.objects.create(
                    name=data["name"], slug=RetailerCreateForm._unique_slug(data["name"]), status=Retailer.Status.PENDING
                )
                user = User(
                    auth_user_id=uuid.UUID(auth_user_id), name=data["staff_name"], role=User.Role.RETAILER_STAFF, retailer=retailer
                )
                user.set_unusable_password()
                user.save()
        except Exception:
            sso.remove_staff(auth_user_id)  # do not leave an enrolled person at auth without a retailer here
            raise
        return retailer


class RetailerCreateForm(forms.Form):
    name = forms.CharField(label="Nom du commerçant", max_length=150)
    staff_email = forms.EmailField(label="E-mail du premier utilisateur")
    staff_password = forms.CharField(
        label="Mot de passe initial", strip=False, widget=forms.PasswordInput(render_value=False)
    )

    def clean_staff_email(self) -> str:
        email = self.cleaned_data["staff_email"].strip().lower()
        if get_user_model().objects.filter(email__iexact=email).exists():
            raise forms.ValidationError("Un compte avec cet e-mail existe déjà.")
        return email

    def clean(self):  # type: ignore[no-untyped-def]
        cleaned = super().clean()
        password = cleaned.get("staff_password")
        if password:
            try:
                validate_password(password, User(email=cleaned.get("staff_email") or ""))
            except forms.ValidationError as exc:
                self.add_error("staff_password", exc)
        return cleaned

    @staticmethod
    def _unique_slug(name: str) -> str:
        base = slugify(name)[:140] or "commercant"
        slug, n = base, 1
        while Retailer.objects.filter(slug=slug).exists():
            n += 1
            slug = f"{base}-{n}"
        return slug

    def save(self) -> Retailer:
        data = self.cleaned_data
        with transaction.atomic():
            retailer = Retailer.objects.create(
                name=data["name"],
                slug=self._unique_slug(data["name"]),
                status=Retailer.Status.PENDING,
            )
            get_user_model().objects.create_user(
                email=data["staff_email"],
                password=data["staff_password"],
                role=User.Role.RETAILER_STAFF,
                retailer=retailer,
            )
        return retailer


class PaymentForm(forms.Form):
    amount = forms.IntegerField(label="Montant (XOF)", min_value=1)
    provider = forms.ChoiceField(label="Moyen de paiement", choices=PaymentMethod.Provider.choices)
    reference = forms.CharField(label="Référence de la transaction", max_length=100)
    period_months = forms.IntegerField(label="Durée (mois)", min_value=1, max_value=36)

    def __init__(self, *args, retailer=None, confirmed_by=None, **kwargs):  # type: ignore[no-untyped-def]
        super().__init__(*args, **kwargs)
        self.retailer = retailer
        self.confirmed_by = confirmed_by

    def save(self):  # type: ignore[no-untyped-def]
        """Record the payment; a repeated (provider, reference) becomes a field error."""
        data = self.cleaned_data
        try:
            return record_payment(
                retailer=self.retailer,
                amount=data["amount"],
                provider=data["provider"],
                reference=data["reference"].strip(),
                period_months=data["period_months"],
                confirmed_by=self.confirmed_by,
            )
        except DuplicatePayment:
            self.add_error("reference", "Cette référence a déjà été enregistrée pour ce moyen.")
            return None
