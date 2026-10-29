from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import F, Q


class Store(models.Model):
    name = models.CharField(max_length=200)
    address = models.CharField(max_length=255)
    city = models.CharField(max_length=120)
    postcode = models.CharField(max_length=20)
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[MinValueValidator(-90), MaxValueValidator(90)],
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[MinValueValidator(-180), MaxValueValidator(180)],
    )
    phone = models.CharField(max_length=50, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class OpeningHours(models.Model):
    """One row per open day; a closed day has no row. weekday 0 = Monday."""

    store = models.ForeignKey(Store, on_delete=models.CASCADE, related_name="opening_hours")
    weekday = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(6)]
    )
    opens = models.TimeField()
    closes = models.TimeField()

    class Meta:
        ordering = ["store", "weekday"]
        verbose_name_plural = "opening hours"
        constraints = [
            models.UniqueConstraint(fields=["store", "weekday"], name="uniq_store_weekday"),
            models.CheckConstraint(
                condition=Q(opens__lt=F("closes")), name="hours_opens_lt_closes"
            ),
            models.CheckConstraint(
                condition=Q(weekday__gte=0, weekday__lte=6), name="hours_weekday_0_6"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.store} day {self.weekday} {self.opens}-{self.closes}"
