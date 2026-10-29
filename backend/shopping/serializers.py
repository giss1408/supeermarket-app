import datetime
from typing import Any

from rest_framework import serializers

from catalog.models import Product

from .models import ListItem, ShoppingList


class ProductSummarySerializer(serializers.ModelSerializer):
    image = serializers.ImageField(read_only=True)

    class Meta:
        model = Product
        fields = ["id", "name", "unit", "image"]


class ListItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(), required=False, allow_null=True
    )

    class Meta:
        model = ListItem
        fields = [
            "id",
            "product",
            "text",
            "quantity",
            "checked",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        instance = self.instance
        product = attrs.get("product", instance.product if instance else None)
        text = attrs.get("text", instance.text if instance else "")
        if product is None and not text.strip():
            raise serializers.ValidationError("Either product or text is required.")
        return attrs

    def to_representation(self, instance: ListItem) -> dict[str, Any]:
        data = super().to_representation(instance)
        data["product"] = (
            ProductSummarySerializer(instance.product, context=self.context).data
            if instance.product_id
            else None
        )
        return data


class ShoppingListSerializer(serializers.ModelSerializer):
    item_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = ShoppingList
        fields = ["id", "name", "item_count", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class ShoppingListDetailSerializer(serializers.ModelSerializer):
    items = serializers.SerializerMethodField()

    class Meta:
        model = ShoppingList
        fields = ["id", "name", "items", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_items(self, obj: ShoppingList) -> list[dict[str, Any]]:
        items = obj.items.select_related("product").order_by("checked", "created_at", "id")
        return ListItemSerializer(items, many=True, context=self.context).data  # type: ignore[return-value]


class UpdatedSinceSerializer(serializers.Serializer):
    updated_since = serializers.DateTimeField(required=False, default_timezone=datetime.UTC)
