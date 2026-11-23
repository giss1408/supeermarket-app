from typing import Any

from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError
from rest_framework import serializers

from accounts import sso
from accounts.sso import SsoError, SsoPrincipal
from common.errors import SessionEndedError, SsoUnavailableError, StepUpRequiredError
from common.messages import msg

from . import services
from .models import PaymentMethod
from .validators import normalize_ci_phone


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
    # Required for the app's own accounts. Staff who signed in through the auth service have
    # no local password: they prove themselves with a
    # fresh password step-up at auth (the token's `auth_time`/`amr`) and a live session check
    # instead, and may leave this out.
    current_password = serializers.CharField(
        write_only=True, style={"input_type": "password"}, trim_whitespace=False, required=False
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
                raise serializers.ValidationError(msg("provider_immutable"))
        elif PaymentMethod.objects.filter(
            retailer=self.context["request"].user.retailer, provider=value
        ).exists():
            raise serializers.ValidationError(msg("provider_exists"))
        return value

    def validate_phone_number(self, value: str) -> str:
        try:
            return normalize_ci_phone(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from None

    def validate_current_password(self, value: str) -> str:
        if not self.context["request"].user.check_password(value):
            raise serializers.ValidationError(msg("incorrect_password"))
        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        principal = self.context["request"].auth
        if isinstance(principal, SsoPrincipal):
            self._sso_step_up(principal)
            attrs.pop("current_password", None)
            return attrs
        # A partial update skips `required`, but the step-up is needed on every write.
        if "current_password" not in attrs:
            raise serializers.ValidationError(
                {"current_password": [msg("current_password_required")]}
            )
        attrs.pop("current_password", None)
        return attrs

    @staticmethod
    def _sso_step_up(principal: SsoPrincipal) -> None:
        """Where customers pay is the retailer's money: a password re-proved within 5 minutes AT
        AUTH, and the session still alive there."""
        try:
            principal.require_step_up(300, amr="pwd")
        except SsoError:
            raise StepUpRequiredError() from None
        alive = sso.session_alive(principal.token)
        if alive is False:
            raise SessionEndedError()
        if alive is None and settings.SSO_MONEY_FAIL_CLOSED:
            raise SsoUnavailableError()

    def create(self, validated_data: dict[str, Any]) -> PaymentMethod:
        try:
            user = self.context["request"].user
            retailer = validated_data.pop("retailer")  # set by the view's perform_create
            return services.create_method(user=user, retailer=retailer, **validated_data)
        except DjangoValidationError as exc:
            raise _to_drf(exc) from None
        except IntegrityError:
            raise serializers.ValidationError({"provider": [msg("provider_exists")]}) from None

    def update(self, instance: PaymentMethod, validated_data: dict[str, Any]) -> PaymentMethod:
        validated_data.pop("provider", None)
        try:
            return services.update_method(
                instance, user=self.context["request"].user, **validated_data
            )
        except DjangoValidationError as exc:
            raise _to_drf(exc) from None
