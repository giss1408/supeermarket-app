from collections.abc import Iterator
from contextlib import contextmanager

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.db.models import Count, Prefetch, ProtectedError, QuerySet
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import serializers, status
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, NotFound
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet

from catalog.models import Category, Product
from common.errors import SubscriptionRequiredError
from common.messages import msg
from common.openapi import ERROR_REF
from common.permissions import IsRetailerStaff
from offers.models import Flyer, Offer
from offers.services import publish_flyer, unpublish_flyer
from retailers.errors import SubscriptionRequired
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
    # Staff-only CRUD; no PUT, role checked on every request. (A comment, not a docstring:
    # spectacular would copy a docstring into every staff operation's description.)

    permission_classes = [IsRetailerStaff]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]
    filter_serializer_class: type[serializers.Serializer] | None = None
    # ORM path from the model to its owning retailer; every queryset goes through scope().
    retailer_lookup: str = "retailer"

    def scope(self, qs: QuerySet, lookup: str | None = None) -> QuerySet:
        """Restrict to the caller's retailer: other retailers' rows are simply not found (404)."""
        if getattr(self, "swagger_fake_view", False):
            return qs.none()
        return qs.filter(**{lookup or self.retailer_lookup: self.request.user.retailer})  # type: ignore[union-attr]

    def filters(self) -> dict:
        """Validated query params (list only); invalid values raise a 400."""
        if self.action != "list" or self.filter_serializer_class is None:
            return {}
        params = self.filter_serializer_class(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        return params.validated_data

    def perform_create(self, serializer: serializers.BaseSerializer) -> None:
        # Content is owned by the creating staff member's retailer.
        serializer.save(retailer=self.request.user.retailer)  # type: ignore[union-attr]

    def destroy(self, request: Request, *args, **kwargs) -> Response:
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError:
            raise Conflict from None


class CategoryViewSet(StaffViewSet):
    serializer_class = StaffCategorySerializer
    ordering = ("sort_order", "id")

    def get_queryset(self) -> QuerySet[Category]:
        return self.scope(Category.objects.all())


@extend_schema_view(list=extend_schema(parameters=[ProductFilterSerializer]))
class ProductViewSet(StaffViewSet):
    serializer_class = StaffProductSerializer
    filter_serializer_class = ProductFilterSerializer
    ordering = ("name", "id")

    def get_queryset(self) -> QuerySet[Product]:
        qs = self.scope(Product.objects.all())
        data = self.filters()
        if "q" in data:
            qs = qs.filter(name__icontains=data["q"])
        if "category" in data:
            qs = qs.filter(category_id=data["category"])
        return qs


@extend_schema_view(list=extend_schema(parameters=[StoreFilterSerializer]))
class StoreViewSet(StaffViewSet):
    serializer_class = StaffStoreSerializer
    filter_serializer_class = StoreFilterSerializer
    ordering = ("name", "id")

    def get_queryset(self) -> QuerySet[Store]:
        qs = self.scope(Store.objects.prefetch_related("opening_hours"))
        data = self.filters()
        if "q" in data:
            qs = qs.filter(name__icontains=data["q"])
        if "is_active" in data:
            qs = qs.filter(is_active=data["is_active"])
        return qs


@extend_schema_view(list=extend_schema(parameters=[OfferFilterSerializer]))
class OfferViewSet(StaffViewSet):
    serializer_class = StaffOfferSerializer
    filter_serializer_class = OfferFilterSerializer
    ordering = ("sort_order", "id")
    retailer_lookup = "flyer__retailer"

    def get_queryset(self) -> QuerySet[Offer]:
        qs = self.scope(Offer.objects.all())
        data = self.filters()
        if "flyer" in data:
            qs = qs.filter(flyer_id=data["flyer"])
        return qs

    @contextmanager
    def _guard_last_offer(self, offer: Offer, new_flyer_id: int | None = None) -> Iterator[None]:
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
            # Scoped to the caller's retailer so a move cannot cross retailers.
            flyers = {
                f.pk: f
                for f in self.scope(Flyer.objects.filter(pk__in=ids), "retailer")
                .order_by("pk")
                .select_for_update()
            }
            if new_flyer_id is not None and new_flyer_id not in flyers:
                # The target was deleted between validation and the lock.
                raise serializers.ValidationError({"flyer": ["Flyer does not exist."]})
            old = flyers[offer.flyer_id]
            if new_flyer_id == offer.flyer_id:
                yield  # already there: not a move
                return
            if old.status == Flyer.Status.PUBLISHED and old.offers.count() <= 1:
                raise serializers.ValidationError(
                    {"flyer": "Cannot remove the last offer of a published flyer; unpublish first."}
                )
            yield

    def perform_create(self, serializer: serializers.BaseSerializer) -> None:
        serializer.save()  # offers belong to their flyer's retailer; no field of their own

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
            # Write only the given fields: a full save() would restore the stale in-memory
            # flyer_id and undo a concurrent move.
            data = serializer.validated_data
            for name, value in data.items():
                setattr(offer, name, value)
            if data:
                offer.save(update_fields=list(data))
            offer.refresh_from_db(fields=["flyer"])


@extend_schema_view(
    list=extend_schema(parameters=[FlyerFilterSerializer]),
    publish=extend_schema(
        request=None,
        responses={
            200: StaffFlyerSerializer,
            403: OpenApiResponse(
                response=ERROR_REF,
                description="The retailer has no active subscription (code subscription_required)",
            ),
        },
    ),
    unpublish=extend_schema(request=None),
)
class FlyerViewSet(StaffViewSet):
    filter_serializer_class = FlyerFilterSerializer
    ordering = ("-valid_from", "-id")

    def get_serializer_class(self):
        return StaffFlyerListSerializer if self.action == "list" else StaffFlyerSerializer

    def get_queryset(self) -> QuerySet[Flyer]:
        if self.action == "list":
            qs = self.scope(Flyer.objects.annotate(offer_count=Count("offers")))
            data = self.filters()
            if "status" in data:
                qs = qs.filter(status=data["status"])
            return qs
        offers = Offer.objects.order_by("sort_order", "id")
        return self.scope(Flyer.objects.prefetch_related(Prefetch("offers", queryset=offers)))

    def _transition(self, service) -> Response:
        flyer = self.get_object()
        try:
            service(flyer)
        except SubscriptionRequired:
            raise SubscriptionRequiredError(msg("subscription_required")) from None
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from None
        return Response(self.get_serializer(flyer).data)

    def perform_destroy(self, instance: Flyer) -> None:
        if instance.status == Flyer.Status.PUBLISHED:
            raise serializers.ValidationError(
                {"status": ["Cannot delete a published flyer; unpublish it first."]}
            )
        super().perform_destroy(instance)

    @action(detail=True, methods=["post"])
    def publish(self, request: Request, pk: str | None = None) -> Response:
        return self._transition(publish_flyer)

    @action(detail=True, methods=["post"])
    def unpublish(self, request: Request, pk: str | None = None) -> Response:
        return self._transition(unpublish_flyer)
