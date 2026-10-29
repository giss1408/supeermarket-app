import math
from typing import Any

from rest_framework import serializers

from .models import OpeningHours, Store


class OpeningHoursSerializer(serializers.ModelSerializer):
    opens = serializers.TimeField(format="%H:%M")
    closes = serializers.TimeField(format="%H:%M")

    class Meta:
        model = OpeningHours
        fields = ["weekday", "opens", "closes"]


class StoreSerializer(serializers.ModelSerializer):
    distance_km = serializers.SerializerMethodField()

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
            "distance_km",
        ]

    def get_distance_km(self, obj: Store) -> float | None:
        value = getattr(obj, "distance_km", None)
        return None if value is None else round(value, 2)


class StoreDetailSerializer(StoreSerializer):
    opening_hours = OpeningHoursSerializer(many=True, read_only=True)

    class Meta(StoreSerializer.Meta):
        fields = [*StoreSerializer.Meta.fields, "opening_hours"]


class StoreQuerySerializer(serializers.Serializer):
    lat = serializers.FloatField(required=False, min_value=-90, max_value=90)
    lng = serializers.FloatField(required=False, min_value=-180, max_value=180)
    q = serializers.CharField(required=False)

    @staticmethod
    def _finite(value: float) -> float:
        if not math.isfinite(value):
            raise serializers.ValidationError("A finite number is required.")
        return value

    def validate_lat(self, value: float) -> float:
        return self._finite(value)

    def validate_lng(self, value: float) -> float:
        return self._finite(value)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if ("lat" in attrs) != ("lng" in attrs):
            missing = "lng" if "lat" in attrs else "lat"
            raise serializers.ValidationError({missing: "lat and lng must be given together."})
        return attrs
