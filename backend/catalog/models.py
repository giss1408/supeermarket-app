from django.core.validators import RegexValidator
from django.db import models

ean_validator = RegexValidator(
    r"^(\d{8}|\d{13})$", "EAN must be exactly 8 or 13 digits.", code="invalid_ean"
)


class Category(models.Model):
    retailer = models.ForeignKey(
        "retailers.Retailer", on_delete=models.PROTECT, related_name="categories"
    )
    name = models.CharField(max_length=120)
    slug = models.SlugField(max_length=120)
    sort_order = models.IntegerField(default=0)

    class Meta:
        ordering = ["sort_order", "name"]
        verbose_name_plural = "categories"
        constraints = [
            models.UniqueConstraint(
                fields=["retailer", "slug"], name="category_retailer_slug_unique"
            )
        ]

    def __str__(self) -> str:
        return self.name


class Product(models.Model):
    retailer = models.ForeignKey(
        "retailers.Retailer", on_delete=models.PROTECT, related_name="products"
    )
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to="products/", blank=True, null=True)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="products")
    unit = models.CharField(max_length=50, blank=True)
    ean = models.CharField(  # noqa: DJ001 - NULL keeps the per-retailer unique optional
        max_length=13, null=True, blank=True, validators=[ean_validator]
    )

    class Meta:
        ordering = ["name"]
        constraints = [
            models.UniqueConstraint(fields=["retailer", "ean"], name="product_retailer_ean_unique")
        ]

    def __str__(self) -> str:
        return self.name

    def save(self, *args, **kwargs):
        if not self.ean:
            self.ean = None
        super().save(*args, **kwargs)
