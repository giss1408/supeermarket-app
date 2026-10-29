from typing import Any

from django.db import transaction
from rest_framework import serializers

from catalog.models import Category, Product
from offers.models import Flyer, Offer
from stores.models import OpeningHours, Store
from uploads.fields import UploadedImageNameField

MAX_ID = 2**31 - 1


class StaffCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ["id", "name", "slug", "sort_order"]


class StaffProductSerializer(serializers.ModelSerializer):
    image_name = UploadedImageNameField(source="image")

    class Meta:
        model = Product
        fields = ["id", "name", "description", "category", "unit", "ean", "image", "image_name"]
        read_only_fields = ["image"]


class OfferFieldsSerializer(serializers.ModelSerializer):
    """Offer fields without the flyer; validates everything the DB constraints enforce."""

    class Meta:
        model = Offer
        fields = [
            "id",
            "product",
            "price",
            "old_price",
            "badge_text",
            "sort_order",
            "valid_from",
            "valid_to",
        ]

    def _current(self, attrs: dict[str, Any], name: str) -> Any:
        if name in attrs:
            return attrs[name]
        return getattr(self.instance, name, None) if self.instance else None

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError("Price must be greater than 0.")
        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        price = self._current(attrs, "price")
        old_price = self._current(attrs, "old_price")
        if price is not None and old_price is not None and old_price <= price:
            raise serializers.ValidationError(
                {"old_price": "old_price must be greater than price."}
            )
        start = self._current(attrs, "valid_from")
        end = self._current(attrs, "valid_to")
        if (start is None) != (end is None):
            missing = "valid_to" if start is not None else "valid_from"
            raise serializers.ValidationError(
                {missing: "valid_from and valid_to must be given together."}
            )
        if start is not None and end is not None and start > end:
            raise serializers.ValidationError(
                {"valid_to": "valid_to must not be before valid_from."}
            )
        return attrs


class StaffOfferSerializer(OfferFieldsSerializer):
    class Meta(OfferFieldsSerializer.Meta):
        fields = ["id", "flyer", *OfferFieldsSerializer.Meta.fields[1:]]


class StaffFlyerListSerializer(serializers.ModelSerializer):
    offer_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Flyer
        fields = [
            "id",
            "title",
            "valid_from",
            "valid_to",
            "status",
            "cover_image",
            "offer_count",
        ]
        read_only_fields = ["status", "cover_image"]


class StaffFlyerSerializer(serializers.ModelSerializer):
    """Create accepts nested ``offers``; PATCH rejects them (use /staff/offers)."""

    offers = OfferFieldsSerializer(many=True, required=False)
    cover_image_name = UploadedImageNameField(source="cover_image")

    class Meta:
        model = Flyer
        fields = [
            "id",
            "title",
            "valid_from",
            "valid_to",
            "status",
            "cover_image",
            "cover_image_name",
            "offers",
        ]
        read_only_fields = ["status", "cover_image"]

    def validate_offers(self, value):
        if self.instance is not None:
            raise serializers.ValidationError(
                "Offers cannot be changed here; use /api/v1/staff/offers."
            )
        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        current = self.instance
        start = attrs.get("valid_from", current.valid_from if current else None)
        end = attrs.get("valid_to", current.valid_to if current else None)
        if start and end and start > end:
            raise serializers.ValidationError(
                {"valid_to": "valid_to must not be before valid_from."}
            )
        if current is not None and current.status == Flyer.Status.PUBLISHED:
            errors: dict[str, Any] = {
                name: "Unpublish the flyer before changing its dates."
                for name in ("valid_from", "valid_to")
                if name in attrs and attrs[name] != getattr(current, name)
            }
            if errors:
                raise serializers.ValidationError(errors)
        return attrs

    @transaction.atomic
    def create(self, validated_data: dict[str, Any]) -> Flyer:
        offers = validated_data.pop("offers", [])
        flyer = Flyer.objects.create(**validated_data)
        Offer.objects.bulk_create([Offer(flyer=flyer, **o) for o in offers])
        return flyer


class OpeningHoursWriteSerializer(serializers.Serializer):
    weekday = serializers.IntegerField(min_value=0, max_value=6)
    opens = serializers.TimeField(format="%H:%M")
    closes = serializers.TimeField(format="%H:%M")

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if attrs["opens"] >= attrs["closes"]:
            raise serializers.ValidationError({"closes": "closes must be after opens."})
        return attrs


class StaffStoreSerializer(serializers.ModelSerializer):
    opening_hours = OpeningHoursWriteSerializer(many=True, required=False)

    class Meta:
        model = Store
        fields = [
            "id",
            "name",
            "address",
            "city",
            "postcode",
            "latitude",
            "longitude",
            "phone",
            "is_active",
            "opening_hours",
        ]

    def validate_opening_hours(self, value):
        days = [h["weekday"] for h in value]
        if len(days) != len(set(days)):
            raise serializers.ValidationError("Each weekday may appear only once.")
        return value

    @staticmethod
    def _write_hours(store: Store, hours: list[dict[str, Any]]) -> None:
        OpeningHours.objects.bulk_create([OpeningHours(store=store, **h) for h in hours])

    @transaction.atomic
    def create(self, validated_data: dict[str, Any]) -> Store:
        hours = validated_data.pop("opening_hours", [])
        store = Store.objects.create(**validated_data)
        self._write_hours(store, hours)
        return store

    @transaction.atomic
    def update(self, instance: Store, validated_data: dict[str, Any]) -> Store:
        hours = validated_data.pop("opening_hours", None)
        instance = super().update(instance, validated_data)
        if hours is not None:
            instance.opening_hours.all().delete()
            self._write_hours(instance, hours)
        return instance


class FlyerFilterSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Flyer.Status.choices, required=False)


class OfferFilterSerializer(serializers.Serializer):
    flyer = serializers.IntegerField(required=False, min_value=1, max_value=MAX_ID)


class ProductFilterSerializer(serializers.Serializer):
    q = serializers.CharField(required=False)
    category = serializers.IntegerField(required=False, min_value=1, max_value=MAX_ID)


class StoreFilterSerializer(serializers.Serializer):
    q = serializers.CharField(required=False)
    # A real BooleanField treats an absent query param as False (HTML-form semantics).
    is_active = serializers.ChoiceField(choices=["true", "false"], required=False)

    def validate_is_active(self, value: str) -> bool:
        return value == "true"
