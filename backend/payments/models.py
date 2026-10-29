from typing import Any

from django.conf import settings
from django.db import models

from .validators import validate_ci_phone


class PaymentMethod(models.Model):
    class Provider(models.TextChoices):
        WAVE = "wave", "Wave"
        ORANGE_MONEY = "orange_money", "Orange Money"
        MTN_MOMO = "mtn_momo", "MTN MoMo"

    provider = models.CharField(max_length=20, choices=Provider.choices, unique=True)
    phone_number = models.CharField(max_length=14, validators=[validate_ci_phone])
    display_name = models.CharField(max_length=100, blank=True)
    instructions = models.CharField(max_length=500, blank=True)
    is_active = models.BooleanField(default=True)  # type: ignore[misc]
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["provider"]

    def __str__(self) -> str:
        return f"{self.get_provider_display()} ({self.phone_number})"


class PaymentMethodChange(models.Model):
    """Append-only audit trail of changes to payment methods."""

    payment_method = models.ForeignKey(
        PaymentMethod, null=True, on_delete=models.SET_NULL, related_name="changes"
    )
    provider = models.CharField(max_length=20)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    changed_by_email = models.CharField(max_length=254, blank=True)
    changed_at = models.DateTimeField(auto_now_add=True)
    old_phone_number = models.CharField(max_length=14, blank=True, null=True)  # noqa: DJ001
    new_phone_number = models.CharField(max_length=14, blank=True, null=True)  # noqa: DJ001
    old_is_active = models.BooleanField(null=True)
    new_is_active = models.BooleanField(null=True)
    old_display_name = models.CharField(max_length=100, blank=True, null=True)  # noqa: DJ001
    new_display_name = models.CharField(max_length=100, blank=True, null=True)  # noqa: DJ001
    old_instructions = models.CharField(max_length=500, blank=True, null=True)  # noqa: DJ001
    new_instructions = models.CharField(max_length=500, blank=True, null=True)  # noqa: DJ001

    class Meta:
        ordering = ["-changed_at", "-id"]

    def __str__(self) -> str:
        return f"{self.provider}: {self.old_phone_number} -> {self.new_phone_number}"

    def save(self, *args: Any, **kwargs: Any) -> None:
        if self.pk is not None:
            raise RuntimeError("PaymentMethodChange rows are append-only.")
        super().save(*args, **kwargs)
