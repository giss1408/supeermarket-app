from django.contrib import admin
from django.http import HttpRequest

from .models import Payment, Retailer, RetailerChange, Subscription


class _ReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj: object | None = None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj: object | None = None) -> bool:
        return False


@admin.register(Retailer)
class RetailerAdmin(admin.ModelAdmin):
    # Status changes must go through retailers.services (they write a RetailerChange row).
    readonly_fields = ["status"]
    list_display = ["name", "slug", "status", "created_at"]
    list_filter = ["status"]
    search_fields = ["name", "slug"]
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Subscription)
class SubscriptionAdmin(_ReadOnlyAdmin):
    list_display = ["retailer", "starts_at", "ends_at"]


@admin.register(Payment)
class PaymentAdmin(_ReadOnlyAdmin):
    list_display = ["retailer", "amount", "provider", "reference", "source", "confirmed_at"]
    list_filter = ["provider", "source"]


@admin.register(RetailerChange)
class RetailerChangeAdmin(_ReadOnlyAdmin):
    list_display = ["retailer", "action", "changed_by_email", "changed_at", "detail"]
    list_filter = ["action"]
