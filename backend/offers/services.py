from django.core.exceptions import ValidationError
from django.db import transaction

from .models import Flyer


def publish_flyer(flyer: Flyer) -> Flyer:
    """Publish a flyer; raises ValidationError if it has no offers or overlaps a published one.

    Locks the flyer and all other published flyers so concurrent publishes serialize.
    Overlap is inclusive: sharing a boundary day overlaps, adjacent days do not.
    """
    with transaction.atomic():
        locked = Flyer.objects.select_for_update().get(pk=flyer.pk)
        others = list(
            Flyer.objects.select_for_update()
            .filter(status=Flyer.Status.PUBLISHED)
            .exclude(pk=locked.pk)
        )
        if not locked.offers.exists():
            raise ValidationError("A flyer needs at least one offer before it can be published.")
        clash = next(
            (
                o
                for o in others
                if o.valid_from <= locked.valid_to and o.valid_to >= locked.valid_from
            ),
            None,
        )
        if clash is not None:
            raise ValidationError(
                f"Dates overlap the published flyer '{clash.title}' "
                f"({clash.valid_from} to {clash.valid_to})."
            )
        flyer.status = locked.status = Flyer.Status.PUBLISHED
        locked.save(update_fields=["status", "updated_at"])
        flyer.updated_at = locked.updated_at
    return flyer


def unpublish_flyer(flyer: Flyer) -> Flyer:
    flyer.status = Flyer.Status.DRAFT
    flyer.save(update_fields=["status", "updated_at"])
    return flyer
