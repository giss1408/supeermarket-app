from rest_framework import serializers

from catalog.serializers import ProductSerializer

from .models import Flyer, Offer


class OfferSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model = Offer
        fields = [
            "id",
            "flyer",
            "price",
            "old_price",
            "badge_text",
            "valid_from",
            "valid_to",
            "product",
        ]


class FlyerListSerializer(serializers.ModelSerializer):
    offer_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Flyer
        fields = ["id", "title", "valid_from", "valid_to", "cover_image", "offer_count"]


class FlyerDetailSerializer(serializers.ModelSerializer):
    offers = OfferSerializer(many=True, read_only=True)

    class Meta:
        model = Flyer
        fields = ["id", "title", "valid_from", "valid_to", "cover_image", "offers"]


class OfferQuerySerializer(serializers.Serializer):
    category = serializers.CharField(required=False)
    q = serializers.CharField(required=False)
    flyer = serializers.IntegerField(required=False)
