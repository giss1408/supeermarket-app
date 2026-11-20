"""The only place that writes Payment, Subscription and RetailerChange rows."""

import calendar
from datetime import datetime
from typing import Any

from django.contrib.auth.base_user import AbstractBaseUser
from django.db import IntegrityError, transaction
from django.utils import timezone

from .errors import DuplicatePayment
from .models import Payment, Retailer, RetailerChange, Subscription


def _add_months(dt: datetime, n: int) -> datetime:
    """Add `n` calendar months, clamping the day to the target month's length."""
    index = dt.month - 1 + n
    year, month = dt.year + index // 12, index % 12 + 1
    day = min(dt.day, calendar.monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


def _who(user: AbstractBaseUser) -> str:
    """Who is named in the audit trail: the e-mail, or, for people who sign in through the auth service (no e-mail here), their auth user id."""
    email = getattr(user, "email", "") or ""
    auth_id = getattr(user, "auth_user_id", None)
    return email or (f"sso:{auth_id}" if auth_id else "")


def _actor(user: AbstractBaseUser | None) -> dict[str, Any]:
    if user is None:
        return {"changed_by": None, "changed_by_email": ""}
    return {"changed_by": user, "changed_by_email": _who(user)}


def _payment_exists(provider: str, reference: str) -> bool:
    return Payment.objects.filter(provider=provider, reference=reference).exists()


def record_payment(
    *,
    retailer: Retailer,
    amount: int,
    provider: str,
    reference: str,
    period_months: int,
    confirmed_by: AbstractBaseUser | None,
    source: str = Payment.Source.MANUAL,
) -> Payment:
    """Record a payment and extend the retailer's subscription by `period_months`.

    Extends from the current end while it is still in the future, otherwise restarts from
    now. Never changes the retailer's status. Raises DuplicatePayment on a repeated
    (provider, reference)."""
    with transaction.atomic():
        if _payment_exists(provider, reference):
            raise DuplicatePayment(f"{provider}:{reference}")
        try:
            with transaction.atomic():
                payment = Payment.objects.create(
                    retailer=retailer,
                    amount=amount,
                    provider=provider,
                    reference=reference,
                    source=source,
                    confirmed_by=confirmed_by,  # type: ignore[misc]
                    period_months=period_months,
                )
        except IntegrityError as exc:
            raise DuplicatePayment(f"{provider}:{reference}") from exc

        now = timezone.now()
        Subscription.objects.get_or_create(
            retailer_id=retailer.pk, defaults={"starts_at": now, "ends_at": now}
        )
        sub = Subscription.objects.select_for_update().get(retailer_id=retailer.pk)
        if sub.ends_at <= now:
            sub.starts_at = now
        sub.ends_at = _add_months(max(now, sub.ends_at), period_months)
        sub.save()

        RetailerChange.objects.create(
            retailer=retailer,
            action=RetailerChange.Action.PAYMENT,
            detail=f"{amount} XOF via {provider} ref {reference}, {period_months} month(s)"[:255],
            **_actor(confirmed_by),
        )
    return payment


def set_status(retailer: Retailer, status: str, *, by: AbstractBaseUser | None) -> Retailer:
    actions = {
        Retailer.Status.ACTIVE: RetailerChange.Action.ACTIVATED,
        Retailer.Status.SUSPENDED: RetailerChange.Action.SUSPENDED,
    }
    if status not in actions:
        raise ValueError(f"Status must be one of {sorted(actions)}, got {status!r}.")
    with transaction.atomic():
        current = Retailer.objects.select_for_update().get(pk=retailer.pk)
        old = current.status
        current.status = status
        current.save(update_fields=["status"])
        RetailerChange.objects.create(
            retailer=current,
            action=actions[status],  # type: ignore[index]
            detail=f"{old} -> {status}",
            **_actor(by),
        )
    retailer.status = status
    return retailer
