from datetime import timedelta

from django.utils import timezone

from retailers.models import Retailer, Subscription


def make_retailer(
    *, slug="shop", status=Retailer.Status.ACTIVE, ends_in: timedelta | None = None
) -> Retailer:
    """Temporary helper; retailer factories arrive in Task 2."""
    retailer = Retailer.objects.create(name=slug.title(), slug=slug, status=status)
    if ends_in is not None:
        now = timezone.now()
        Subscription.objects.create(retailer=retailer, starts_at=now, ends_at=now + ends_in)
    return retailer
