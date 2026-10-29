from collections.abc import Iterator
from contextlib import contextmanager

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.db.models import Count, Prefetch, ProtectedError, QuerySet
from rest_framework import serializers, status
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, NotFound
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

    @staticmethod
    @contextmanager
    def _guard_last_offer(offer: Offer, new_flyer_id: int | None = None) -> Iterator[None]:
        """Run the enclosed write under row locks, refusing to empty a published flyer.

        Locks the old flyer (and the target flyer when moving) in ascending id order so two
        opposite moves cannot deadlock, then re-counts the old flyer's offers under the lock.
        """
        with transaction.atomic():
            # Re-read the offer under lock: it may have moved or been deleted since it was loaded.
            try:
                current = Offer.objects.select_for_update().only("flyer_id").get(pk=offer.pk)
            except Offer.DoesNotExist:
                raise NotFound from None
            offer.flyer_id = current.flyer_id
            ids = {offer.flyer_id, *([new_flyer_id] if new_flyer_id else [])}
            # Evaluated and ordered so rows are locked in ascending id order (no deadlocks).
            flyers = {
                f.pk: f for f in Flyer.objects.filter(pk__in=ids).order_by("pk").select_for_update()
            }
            old = flyers[offer.flyer_id]
            if new_flyer_id == offer.flyer_id:
                yield  # already there: not a move
                return
            if old.status == Flyer.Status.PUBLISHED and old.offers.count() <= 1:
                raise serializers.ValidationError(
                    {"flyer": "Cannot remove the last offer of a published flyer; unpublish first."}
                )
            yield

    def perform_destroy(self, instance: Offer) -> None:
        with self._guard_last_offer(instance):
            instance.delete()

    def perform_update(self, serializer: serializers.BaseSerializer) -> None:
        offer: Offer = serializer.instance  # type: ignore[assignment]
        new_flyer = serializer.validated_data.get("flyer")
        if new_flyer is not None:
            with self._guard_last_offer(offer, new_flyer.pk):
                serializer.save()
        else:
            serializer.save()


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
