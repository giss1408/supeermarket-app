from typing import Any

from django.contrib.auth.password_validation import validate_password
from django.db import IntegrityError
from rest_framework import serializers
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from common.messages import msg

from .models import LoyaltyCard, User


def _email_taken(email: str) -> bool:
    return User.objects.filter(email__iexact=email).exists()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, style={"input_type": "password"})

    class Meta:
        model = User
        fields = ["id", "email", "password", "name", "role"]
        read_only_fields = ["id", "role"]
        extra_kwargs: dict[str, Any] = {"email": {"validators": []}}

    def validate_email(self, value: str) -> str:
        value = value.lower()
        if _email_taken(value):
            raise serializers.ValidationError(msg("email_taken"))
        return value

    def validate_password(self, value: str) -> str:
        validate_password(value)
        return value

    def create(self, validated_data: dict[str, Any]) -> User:
        try:
            return User.objects.create_user(**validated_data)
        except IntegrityError as exc:
            raise serializers.ValidationError({"email": [msg("email_taken")]}) from exc


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()

    def validate_refresh(self, value: str) -> str:
        try:
            RefreshToken(value)  # type: ignore[arg-type]
        except TokenError as exc:
            raise serializers.ValidationError(msg("invalid_token")) from exc
        return value

    def save(self, **kwargs: Any) -> None:
        try:
            RefreshToken(self.validated_data["refresh"]).blacklist()  # type: ignore[arg-type]
        except TokenError as exc:
            raise serializers.ValidationError({"refresh": [msg("invalid_token")]}) from exc


class MeSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "email", "name", "role"]
        read_only_fields = ["id", "email", "role"]


class CardSerializer(serializers.ModelSerializer):
    barcode_value = serializers.CharField(source="number", read_only=True)

    class Meta:
        model = LoyaltyCard
        fields = ["number", "barcode_value"]
