from typing import Any

from django import forms
from django.contrib import admin
from django.db import transaction
from django.db.models import QuerySet
from django.http import HttpRequest

from . import services
from .models import PaymentMethod, PaymentMethodChange
from .validators import normalize_ci_phone


class PaymentMethodForm(forms.ModelForm):
    class Meta:
        model = PaymentMethod
        fields = ["provider", "phone_number", "display_name", "instructions", "is_active"]

    def clean_phone_number(self) -> str:
        return normalize_ci_phone(self.cleaned_data["phone_number"])


@admin.register(PaymentMethod)
class PaymentMethodAdmin(admin.ModelAdmin):
    form = PaymentMethodForm
    list_display = ["provider", "phone_number", "display_name", "is_active", "updated_at"]
    list_filter = ["is_active"]

    def get_readonly_fields(self, request: HttpRequest, obj: PaymentMethod | None = None):
        return ["provider"] if obj else []

    def save_model(
        self, request: HttpRequest, obj: PaymentMethod, form: forms.ModelForm, change: bool
    ) -> None:
        data = {k: v for k, v in form.cleaned_data.items() if k in form.fields}
        if change:
            services.update_method(obj, user=request.user, **data)  # type: ignore[arg-type]
        else:
            created = services.create_method(user=request.user, **data)  # type: ignore[arg-type]
            obj.pk = created.pk
            obj._state.adding = False
            obj.updated_at = created.updated_at

    def delete_model(self, request: HttpRequest, obj: PaymentMethod) -> None:
        services.delete_method(obj, user=request.user)  # type: ignore[arg-type]

    def delete_queryset(self, request: HttpRequest, queryset: QuerySet[PaymentMethod]) -> None:
        with transaction.atomic():
            for obj in queryset:
                services.delete_method(obj, user=request.user)  # type: ignore[arg-type]


@admin.register(PaymentMethodChange)
class PaymentMethodChangeAdmin(admin.ModelAdmin):
    list_display = [
        "changed_at",
        "provider",
        "changed_by_email",
        "old_phone_number",
        "new_phone_number",
        "old_is_active",
        "new_is_active",
    ]
    list_filter = ["provider", "changed_at"]
    search_fields = ["changed_by_email", "old_phone_number", "new_phone_number"]
    date_hierarchy = "changed_at"

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False
