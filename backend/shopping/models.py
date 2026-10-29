from typing import Any

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver
from django.utils import timezone


class ShoppingList(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="shopping_lists"
    )
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return self.name


class ListItem(models.Model):
    list = models.ForeignKey(ShoppingList, on_delete=models.CASCADE, related_name="items")
    # CASCADE on purpose: deleting a catalog product removes it from users' lists instead of
    # blocking the delete (PROTECT) or violating the product-or-text constraint (SET_NULL).
    product = models.ForeignKey("catalog.Product", null=True, blank=True, on_delete=models.CASCADE)
    text = models.CharField(max_length=200, blank=True)
    quantity = models.PositiveIntegerField(
        default=1, validators=[MinValueValidator(1), MaxValueValidator(999)]
    )
    checked = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(product__isnull=False) | ~models.Q(text=""),
                name="listitem_product_or_text",
            ),
            models.CheckConstraint(
                condition=models.Q(quantity__gte=1), name="listitem_quantity_gte_1"
            ),
        ]

    def __str__(self) -> str:
        return self.text or f"product {self.product_id}"


def _bump_list(list_id: int) -> None:
    ShoppingList.objects.filter(pk=list_id).update(updated_at=timezone.now())


@receiver(post_save, sender=ListItem)
def _item_saved(sender: Any, instance: ListItem, **kwargs: Any) -> None:
    """Item changes must show up in ``updated_since`` sync of the parent list."""
    _bump_list(instance.list_id)


@receiver(post_delete, sender=ListItem)
def _item_deleted(sender: Any, instance: ListItem, **kwargs: Any) -> None:
    _bump_list(instance.list_id)
