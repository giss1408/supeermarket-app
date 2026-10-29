"""The only place that writes PaymentMethod rows. Every write leaves one audit row."""

from typing import Any

from django.contrib.auth.base_user import AbstractBaseUser
from django.db import transaction

from .models import PaymentMethod, PaymentMethodChange
from .validators import normalize_ci_phone

_UPDATABLE = ("phone_number", "display_name", "instructions", "is_active")


def _actor(user: AbstractBaseUser | None) -> dict[str, Any]:
    if user is None:
        return {"changed_by": None, "changed_by_email": ""}
    return {"changed_by": user, "changed_by_email": getattr(user, "email", "")}


def create_method(*, user: AbstractBaseUser | None, **fields: Any) -> PaymentMethod:
    if "phone_number" in fields:
        fields["phone_number"] = normalize_ci_phone(fields["phone_number"])
    with transaction.atomic():
        method = PaymentMethod(**fields)
        method.full_clean()
        method.save()
        PaymentMethodChange.objects.create(
            payment_method=method,
            provider=method.provider,
            new_phone_number=method.phone_number,
            new_is_active=method.is_active,
            **_actor(user),
        )
    return method


def update_method(
    method: PaymentMethod, *, user: AbstractBaseUser | None, **fields: Any
) -> PaymentMethod:
    """Update editable fields. An audit row is written only when the phone number or
    ``is_active`` actually changed; the provider can never be changed."""
    fields.pop("provider", None)
    if "phone_number" in fields:
        fields["phone_number"] = normalize_ci_phone(fields["phone_number"])
    with transaction.atomic():
        old = PaymentMethod.objects.select_for_update().get(pk=method.pk)
        for name in _UPDATABLE:
            if name in fields:
                setattr(method, name, fields[name])
        method.full_clean()
        method.save()
        if (old.phone_number, old.is_active) != (method.phone_number, method.is_active):
            PaymentMethodChange.objects.create(
                payment_method=method,
                provider=method.provider,
                old_phone_number=old.phone_number,
                new_phone_number=method.phone_number,
                old_is_active=old.is_active,
                new_is_active=method.is_active,
                **_actor(user),
            )
    return method


def delete_method(method: PaymentMethod, *, user: AbstractBaseUser | None) -> None:
    with transaction.atomic():
        old = PaymentMethod.objects.select_for_update().get(pk=method.pk)
        PaymentMethodChange.objects.create(
            payment_method=None,
            provider=old.provider,
            old_phone_number=old.phone_number,
            old_is_active=old.is_active,
            **_actor(user),
        )
        old.delete()
