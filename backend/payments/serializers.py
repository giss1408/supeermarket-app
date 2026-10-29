from typing import Any

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError
from rest_framework import serializers

from . import services
from .models import PaymentMethod
from .validators import normalize_ci_phone

_DUPLICATE_PROVIDER = "A payment method for this provider already exists."


class PaymentMethodSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentMethod
        fields = ["provider", "phone_number", "display_name", "instructions", "updated_at"]


def _to_drf(exc: DjangoValidationError) -> serializers.ValidationError:
    if hasattr(exc, "error_dict"):
        return serializers.ValidationError(exc.message_dict)
    return serializers.ValidationError({"non_field_errors": exc.messages})


class StaffPaymentMethodSerializer(serializers.ModelSerializer):
    # Not the model validator: it only accepts the normalised form, and input is normalised here.
    phone_number = serializers.CharField(max_length=50)
    current_password = serializers.CharField(
        write_only=True, style={"input_type": "password"}, trim_whitespace=False
    )

    class Meta:
        model = PaymentMethod
        fields = [
            "id",
            "provider",
            "phone_number",
            "display_name",
            "instructions",
            "is_active",
            "updated_at",
            "current_password",
        ]
        read_only_fields = ["id", "updated_at"]
        extra_kwargs: dict[str, Any] = {"provider": {"validators": []}}

    def validate_provider(self, value: str) -> str:
        if self.instance is not None:
            if value != self.instance.provider:
                raise serializers.ValidationError("The provider of a payment method cannot change.")
        elif PaymentMethod.objects.filter(provider=value).exists():
            raise serializers.ValidationError(_DUPLICATE_PROVIDER)
        return value

    def validate_phone_number(self, value: str) -> str:
        try:
            return normalize_ci_phone(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from None

    def validate_current_password(self, value: str) -> str:
        if not self.context["request"].user.check_password(value):
            raise serializers.ValidationError("Incorrect password.")
        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        # A partial update skips `required`, but the step-up is needed on every write.
        if "current_password" not in attrs:
            raise serializers.ValidationError({"current_password": ["This field is required."]})
        attrs.pop("current_password", None)
        return attrs

    def create(self, validated_data: dict[str, Any]) -> PaymentMethod:
        try:
            return services.create_method(user=self.context["request"].user, **validated_data)
        except DjangoValidationError as exc:
            raise _to_drf(exc) from None
        except IntegrityError:
            raise serializers.ValidationError({"provider": [_DUPLICATE_PROVIDER]}) from None

    def update(self, instance: PaymentMethod, validated_data: dict[str, Any]) -> PaymentMethod:
        validated_data.pop("provider", None)
        try:
            return services.update_method(
                instance, user=self.context["request"].user, **validated_data
            )
        except DjangoValidationError as exc:
            raise _to_drf(exc) from None
