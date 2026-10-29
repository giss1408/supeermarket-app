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
            new_display_name=method.display_name,
            new_instructions=method.instructions,
            **_actor(user),
        )
    return method


def update_method(
    method: PaymentMethod, *, user: AbstractBaseUser | None, **fields: Any
) -> PaymentMethod:
    """Update editable fields on the locked, current DB row (never the caller's possibly
    stale copy). An audit row is written whenever phone_number, is_active, display_name
    or instructions differ from the stored values; the provider can never be changed."""
    fields.pop("provider", None)
    if "phone_number" in fields:
        fields["phone_number"] = normalize_ci_phone(fields["phone_number"])
    with transaction.atomic():
        current = PaymentMethod.objects.select_for_update().get(pk=method.pk)
        before = {name: getattr(current, name) for name in _UPDATABLE}
        for name in _UPDATABLE:
            if name in fields:
                setattr(current, name, fields[name])
        current.full_clean()
        current.save()
        if before != {name: getattr(current, name) for name in _UPDATABLE}:
            PaymentMethodChange.objects.create(
                payment_method=current,
                provider=current.provider,
                old_phone_number=before["phone_number"],
                new_phone_number=current.phone_number,
                old_is_active=before["is_active"],
                new_is_active=current.is_active,
                old_display_name=before["display_name"],
                new_display_name=current.display_name,
                old_instructions=before["instructions"],
                new_instructions=current.instructions,
                **_actor(user),
            )
    for name in (*_UPDATABLE, "updated_at"):
        setattr(method, name, getattr(current, name))
    return method


def delete_method(method: PaymentMethod, *, user: AbstractBaseUser | None) -> None:
    with transaction.atomic():
        old = PaymentMethod.objects.select_for_update().get(pk=method.pk)
        PaymentMethodChange.objects.create(
            payment_method=None,
            provider=old.provider,
            old_phone_number=old.phone_number,
            old_is_active=old.is_active,
            old_display_name=old.display_name,
            old_instructions=old.instructions,
            **_actor(user),
        )
        old.delete()
