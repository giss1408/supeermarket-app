from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import AuthenticationForm
from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from django.utils.text import slugify

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


class RetailerCreateForm(forms.Form):
    name = forms.CharField(label="Nom du commerçant", max_length=150)
    staff_email = forms.EmailField(label="E-mail du premier utilisateur")
    staff_password = forms.CharField(
        label="Mot de passe initial", widget=forms.PasswordInput(render_value=False)
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
