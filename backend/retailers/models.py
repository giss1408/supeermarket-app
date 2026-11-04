from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db import models
from django.utils import timezone


class RetailerQuerySet(models.QuerySet["Retailer"]):
    def expiring(self, days: int = 7) -> "RetailerQuerySet":
        """Active retailers whose subscription ends within the next `days` days."""
        now = timezone.now()
        return self.filter(
            status=Retailer.Status.ACTIVE,
            subscription__ends_at__gt=now,
            subscription__ends_at__lte=now + timedelta(days=days),
        )

    def lapsed(self) -> "RetailerQuerySet":
        """Active retailers whose subscription has already ended."""
        return self.filter(status=Retailer.Status.ACTIVE, subscription__ends_at__lte=timezone.now())


class Retailer(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACTIVE = "active", "Active"
        SUSPENDED = "suspended", "Suspended"

    name = models.CharField(max_length=150)
    slug = models.SlugField(unique=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = RetailerQuerySet.as_manager()

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name

    @property
    def can_publish(self) -> bool:
        if self.status != self.Status.ACTIVE:
            return False
        return Subscription.objects.filter(retailer=self, ends_at__gt=timezone.now()).exists()


class Subscription(models.Model):
    retailer = models.OneToOneField(Retailer, on_delete=models.CASCADE, related_name="subscription")
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()

    def __str__(self) -> str:
        return f"{self.retailer} until {self.ends_at:%Y-%m-%d}"


class Payment(models.Model):
    """Append-only record of a subscription payment (XOF, whole amounts)."""

    class Source(models.TextChoices):
        MANUAL = "manual", "Manual"
        WEBHOOK = "webhook", "Webhook"

    retailer = models.ForeignKey(Retailer, on_delete=models.CASCADE, related_name="payments")
    amount = models.PositiveIntegerField()
    provider = models.CharField(max_length=20)
    reference = models.CharField(max_length=100)
    source = models.CharField(max_length=10, choices=Source.choices, default=Source.MANUAL)
    confirmed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    confirmed_at = models.DateTimeField(default=timezone.now)
    period_months = models.PositiveSmallIntegerField()

    class Meta:
        ordering = ["-confirmed_at", "-id"]
        constraints = [
            models.UniqueConstraint(fields=["provider", "reference"], name="uniq_payment_ref")
        ]

    def __str__(self) -> str:
        return f"{self.provider}:{self.reference} ({self.amount} XOF)"

    def save(self, *args: Any, **kwargs: Any) -> None:
        if self.pk is not None:
            raise RuntimeError("Payment rows are append-only.")
        super().save(*args, **kwargs)


class RetailerChange(models.Model):
    """Append-only audit trail of retailer status and payment events."""

    class Action(models.TextChoices):
        ACTIVATED = "activated", "Activated"
        SUSPENDED = "suspended", "Suspended"
        PAYMENT = "payment", "Payment"

    retailer = models.ForeignKey(Retailer, on_delete=models.CASCADE, related_name="changes")
    action = models.CharField(max_length=10, choices=Action.choices)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    changed_by_email = models.CharField(max_length=254, blank=True)
    changed_at = models.DateTimeField(auto_now_add=True)
    detail = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-changed_at", "-id"]

    def __str__(self) -> str:
        return f"{self.retailer}: {self.action}"

    def save(self, *args: Any, **kwargs: Any) -> None:
        if self.pk is not None:
            raise RuntimeError("RetailerChange rows are append-only.")
        super().save(*args, **kwargs)
