from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.db.models import Count, Prefetch, ProtectedError, QuerySet
from rest_framework import serializers, status
from rest_framework.decorators import action
from rest_framework.exceptions import APIException
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from catalog.models import Category, Product
from common.permissions import IsStaff
from offers.models import Flyer, Offer
from offers.services import publish_flyer, unpublish_flyer
from stores.models import Store

from .serializers import (
    FlyerFilterSerializer,
    OfferFilterSerializer,
    ProductFilterSerializer,
    StaffCategorySerializer,
    StaffFlyerListSerializer,
    StaffFlyerSerializer,
    StaffOfferSerializer,
    StaffProductSerializer,
    StaffStoreSerializer,
    StoreFilterSerializer,
)


class Conflict(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = "This object is still referenced by other objects and cannot be deleted."
    default_code = "conflict"


class StaffViewSet(ModelViewSet):
    """Staff-only CRUD; no PUT, role checked on every request."""

    permission_classes = [IsStaff]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]
    filter_serializer_class: type[serializers.Serializer] | None = None

    def filters(self) -> dict:
        """Validated query params (list only); invalid values raise a 400."""
        if self.action != "list" or self.filter_serializer_class is None:
            return {}
        params = self.filter_serializer_class(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        return params.validated_data

    def destroy(self, request: Request, *args, **kwargs) -> Response:
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError:
            raise Conflict from None


class CategoryViewSet(StaffViewSet):
    queryset = Category.objects.all()
    serializer_class = StaffCategorySerializer
    ordering = ("sort_order", "id")


class ProductViewSet(StaffViewSet):
    serializer_class = StaffProductSerializer
    filter_serializer_class = ProductFilterSerializer
    ordering = ("name", "id")

    def get_queryset(self) -> QuerySet[Product]:
        qs = Product.objects.all()
        data = self.filters()
        if "q" in data:
            qs = qs.filter(name__icontains=data["q"])
        if "category" in data:
            qs = qs.filter(category_id=data["category"])
        return qs


class StoreViewSet(StaffViewSet):
    serializer_class = StaffStoreSerializer
    filter_serializer_class = StoreFilterSerializer
    ordering = ("name", "id")

    def get_queryset(self) -> QuerySet[Store]:
        qs = Store.objects.prefetch_related("opening_hours")
        data = self.filters()
        if "q" in data:
            qs = qs.filter(name__icontains=data["q"])
        if "is_active" in data:
            qs = qs.filter(is_active=data["is_active"])
        return qs


class OfferViewSet(StaffViewSet):
    serializer_class = StaffOfferSerializer
    filter_serializer_class = OfferFilterSerializer
    ordering = ("sort_order", "id")

    def get_queryset(self) -> QuerySet[Offer]:
        qs = Offer.objects.all()
        data = self.filters()
        if "flyer" in data:
            qs = qs.filter(flyer_id=data["flyer"])
        return qs

    def perform_destroy(self, instance: Offer) -> None:
        with transaction.atomic():
            flyer = Flyer.objects.select_for_update().get(pk=instance.flyer_id)
            if flyer.status == Flyer.Status.PUBLISHED and flyer.offers.count() <= 1:
                raise serializers.ValidationError(
                    "Cannot remove the last offer of a published flyer; unpublish it first."
                )
            instance.delete()


class FlyerViewSet(StaffViewSet):
    filter_serializer_class = FlyerFilterSerializer
    ordering = ("-valid_from", "-id")

    def get_serializer_class(self):
        return StaffFlyerListSerializer if self.action == "list" else StaffFlyerSerializer

    def get_queryset(self) -> QuerySet[Flyer]:
        if self.action == "list":
            qs = Flyer.objects.annotate(offer_count=Count("offers"))
            data = self.filters()
            if "status" in data:
                qs = qs.filter(status=data["status"])
            return qs
        offers = Offer.objects.order_by("sort_order", "id")
        return Flyer.objects.prefetch_related(Prefetch("offers", queryset=offers))

    def _transition(self, service) -> Response:
        flyer = self.get_object()
        try:
            service(flyer)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from None
        return Response(self.get_serializer(flyer).data)

    @action(detail=True, methods=["post"])
    def publish(self, request: Request, pk: str | None = None) -> Response:
        return self._transition(publish_flyer)

    @action(detail=True, methods=["post"])
    def unpublish(self, request: Request, pk: str | None = None) -> Response:
        return self._transition(unpublish_flyer)
