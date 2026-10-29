from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import LoyaltyCard, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ["email"]
    list_display = ["email", "name", "role", "is_staff", "is_active"]
    list_filter = ["role", "is_staff", "is_active"]
    search_fields = ["email", "name"]
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("name", "role")}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        ("Dates", {"fields": ("last_login", "created_at")}),
    )
    readonly_fields = ["created_at", "last_login"]
    add_fieldsets = (
        (
            None,
            {"classes": ("wide",), "fields": ("email", "name", "role", "password1", "password2")},
        ),
    )
    filter_horizontal = ("groups", "user_permissions")


@admin.register(LoyaltyCard)
class LoyaltyCardAdmin(admin.ModelAdmin):
    list_display = ["number", "user"]
    search_fields = ["number", "user__email"]
