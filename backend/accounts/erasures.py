"""Telling the auth service a person was erased, with a retry. The product keeps only the opaque auth user id (no phone number, no name) and only
until auth answers (or AUTH_ERASE_MAX_DAYS, default 30, then it gives up and logs it for a person to look at)."""

import logging
import os
from datetime import timedelta

from django.utils import timezone

from . import sso
from .models import AuthErasure

log = logging.getLogger("supermarket.erasures")


def _delay(attempts: int) -> timedelta:
    return timedelta(minutes=min(2 ** max(attempts - 1, 0), 360))  # 1 min, 2, 4... capped at 6 hours


def max_age() -> timedelta:
    return timedelta(days=int(os.environ.get("AUTH_ERASE_MAX_DAYS", "30")))


def tell_auth(auth_user_id) -> None:  # type: ignore[no-untyped-def]
    """Right after the person's data is gone. Never raises: the deletion stands whatever auth does."""
    try:
        if sso.erase_identity(auth_user_id) is False:
            now = timezone.now()
            AuthErasure.objects.create(auth_user_id=auth_user_id, attempts=1, next_attempt_at=now + _delay(1))
    except Exception:  # never let bookkeeping undo or hide a deletion
        log.error("auth erase could not even be queued: the person is deleted here but her auth identity remains")


def process(now=None, limit: int = 50) -> dict[str, int]:  # type: ignore[no-untyped-def]
    """Retries what is due. Counts only."""
    now = now or timezone.now()
    out = {"done": 0, "retry": 0, "gave_up": 0, "purged": 0}
    for row in AuthErasure.objects.filter(status="pending", next_attempt_at__lte=now).order_by("id")[:limit]:
        outcome = sso.erase_identity(row.auth_user_id)
        if outcome is not False:  # answered, or SSO switched off meanwhile: nothing left to tell
            row.status, row.finished_at = "done", now
            out["done"] += 1
        elif now - row.created_at > max_age():
            log.error("auth erase GIVEN UP (id %s): erase her auth identity by hand", row.id)
            row.status, row.finished_at = "gave_up", now
            out["gave_up"] += 1
        else:
            row.attempts += 1
            row.next_attempt_at = now + _delay(row.attempts)
            out["retry"] += 1
        row.save()
    out["purged"] = AuthErasure.objects.exclude(status="pending").filter(finished_at__lt=now - timedelta(days=7)).delete()[0]
    return out
