from django.contrib import admin, messages
from django.core.exceptions import ValidationError

from .models import Flyer, Offer
from .services import publish_flyer, unpublish_flyer


class OfferInline(admin.TabularInline):
    model = Offer
    extra = 0
    autocomplete_fields = ["product"]


@admin.register(Flyer)
class FlyerAdmin(admin.ModelAdmin):
    list_display = ["title", "valid_from", "valid_to", "status", "updated_at"]
    list_filter = ["status"]
    search_fields = ["title"]
    readonly_fields = ["status", "created_at", "updated_at"]
    inlines = [OfferInline]
    actions = ["publish_selected", "unpublish_selected"]

    @admin.action(description="Publish selected flyers")
    def publish_selected(self, request, queryset):
        for flyer in queryset:
            try:
                publish_flyer(flyer)
            except ValidationError as exc:
                self.message_user(
                    request, f"{flyer.title}: {' '.join(exc.messages)}", messages.ERROR
                )
            else:
                self.message_user(request, f"Published {flyer.title}.", messages.SUCCESS)

    @admin.action(description="Unpublish selected flyers (back to draft)")
    def unpublish_selected(self, request, queryset):
        for flyer in queryset:
            unpublish_flyer(flyer)
        self.message_user(request, "Unpublished.", messages.SUCCESS)


@admin.register(Offer)
class OfferAdmin(admin.ModelAdmin):
    list_display = ["product", "flyer", "price", "old_price", "badge_text", "sort_order"]
    list_filter = ["flyer"]
    search_fields = ["product__name", "flyer__title", "badge_text"]
    autocomplete_fields = ["product"]
