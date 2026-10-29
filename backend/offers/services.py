from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from .models import Flyer


def _find_overlap(flyer: Flyer) -> Flyer | None:
    """Another published flyer whose dates overlap (inclusive) this one's."""
    return (
        Flyer.objects.filter(
            status=Flyer.Status.PUBLISHED,
            valid_from__lte=flyer.valid_to,
            valid_to__gte=flyer.valid_from,
        )
        .exclude(pk=flyer.pk)
        .first()
    )


def _overlap_message(clash: Flyer | None) -> str:
    if clash is None:
        return "Dates overlap another published flyer."
    return (
        f"Dates overlap the published flyer '{clash.title}' "
        f"({clash.valid_from} to {clash.valid_to})."
    )


def publish_flyer(flyer: Flyer) -> Flyer:
    """Publish a flyer; raises ValidationError if it has no offers or overlaps a published one.

    Overlap is inclusive (sharing a boundary day overlaps, adjacent days do not). The friendly
    check runs first; the database exclusion constraint is the real guarantee, and a race loser's
    IntegrityError is re-raised as the same ValidationError.
    """
    try:
        with transaction.atomic():
            locked = Flyer.objects.select_for_update().get(pk=flyer.pk)
            if not locked.offers.exists():
                raise ValidationError(
                    "A flyer needs at least one offer before it can be published."
                )
            clash = _find_overlap(locked)
            if clash is not None:
                raise ValidationError(_overlap_message(clash))
            locked.status = Flyer.Status.PUBLISHED
            locked.save(update_fields=["status", "updated_at"])
    except IntegrityError:
        raise ValidationError(_overlap_message(_find_overlap(locked))) from None
    flyer.status = locked.status
    flyer.updated_at = locked.updated_at
    return flyer


def unpublish_flyer(flyer: Flyer) -> Flyer:
    flyer.status = Flyer.Status.DRAFT
    flyer.save(update_fields=["status", "updated_at"])
    return flyer
