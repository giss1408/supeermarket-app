from django.core.validators import RegexValidator
from django.db import models

ean_validator = RegexValidator(
    r"^(\d{8}|\d{13})$", "EAN must be exactly 8 or 13 digits.", code="invalid_ean"
)


class Category(models.Model):
    name = models.CharField(max_length=120)
    slug = models.SlugField(max_length=120, unique=True)
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "categories"

    def __str__(self) -> str:
        return self.name


class Product(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to="products/", blank=True, null=True)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="products")
    unit = models.CharField(max_length=50, blank=True)
    ean = models.CharField(
        max_length=13, null=True, blank=True, unique=True, validators=[ean_validator]
    )

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name

    def save(self, *args, **kwargs):
        if not self.ean:
            self.ean = None
        super().save(*args, **kwargs)
