from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import F, Q


class Flyer(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        PUBLISHED = "published", "Published"

    title = models.CharField(max_length=200)
    valid_from = models.DateField()
    valid_to = models.DateField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    cover_image = models.ImageField(upload_to="flyers/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-valid_from", "-id"]
        constraints = [
            models.CheckConstraint(
                condition=Q(valid_from__lte=F("valid_to")), name="flyer_valid_from_lte_valid_to"
            ),
        ]

    def __str__(self) -> str:
        return self.title

    def clean(self):
        super().clean()
        if self.valid_from and self.valid_to and self.valid_from > self.valid_to:
            raise ValidationError({"valid_to": "valid_to must not be before valid_from."})


class Offer(models.Model):
    flyer = models.ForeignKey(Flyer, on_delete=models.CASCADE, related_name="offers")
    product = models.ForeignKey("catalog.Product", on_delete=models.PROTECT, related_name="offers")
    price = models.DecimalField(max_digits=10, decimal_places=2)
    old_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    badge_text = models.CharField(max_length=60, blank=True)
    sort_order = models.IntegerField(default=0)
    valid_from = models.DateField(null=True, blank=True)
    valid_to = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ["sort_order", "id"]
        constraints = [
            models.CheckConstraint(condition=Q(price__gt=0), name="offer_price_gt_0"),
            models.CheckConstraint(
                condition=Q(old_price__isnull=True) | Q(old_price__gt=F("price")),
                name="offer_old_price_gt_price",
            ),
            models.CheckConstraint(
                condition=Q(valid_from__isnull=True, valid_to__isnull=True)
                | Q(
                    valid_from__isnull=False, valid_to__isnull=False, valid_from__lte=F("valid_to")
                ),
                name="offer_valid_dates_ordered",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.product} @ {self.price}"
