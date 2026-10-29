from typing import Any

from django.db.models import FloatField, Prefetch, Q, QuerySet, Value
from django.db.models.functions import ASin, Cast, Cos, Least, Power, Radians, Sin, Sqrt
from rest_framework.generics import ListAPIView, RetrieveAPIView

from common.pagination import DefaultCursorPagination
from common.views import PublicReadMixin

from .models import OpeningHours, Store
from .serializers import StoreDetailSerializer, StoreQuerySerializer, StoreSerializer

EARTH_RADIUS_KM = 6371.0088


class StorePagination(DefaultCursorPagination):
    page_size = 20


def _float(field: str) -> Cast:
    return Cast(field, FloatField())


def annotate_distance(qs: QuerySet[Store], lat: float, lng: float) -> QuerySet[Store]:
    """Add ``distance_km`` (haversine, great-circle) computed in the database."""
    lat1 = Radians(Value(lat))
    lat2 = Radians(_float("latitude"))
    dlat = lat2 - lat1
    dlng = Radians(_float("longitude")) - Radians(Value(lng))
    a = Power(Sin(dlat / 2), 2) + Cos(lat1) * Cos(lat2) * Power(Sin(dlng / 2), 2)
    # Least() guards against a hair over 1.0 from float rounding (sqrt/asin domain).
    distance = 2 * EARTH_RADIUS_KM * ASin(Sqrt(Least(a, Value(1.0))))
    return qs.annotate(distance_km=Cast(distance, FloatField()))


class _StoreQueryMixin:
    request: Any

    def _params(self) -> dict[str, Any]:
        cached = getattr(self.request, "_store_params", None)
        if cached is None:
            ser = StoreQuerySerializer(data=self.request.query_params)
            ser.is_valid(raise_exception=True)
            cached = self.request._store_params = ser.validated_data
        return cached


class StoreListView(_StoreQueryMixin, PublicReadMixin, ListAPIView):
    serializer_class = StoreSerializer
    pagination_class = StorePagination

    @property
    def ordering(self) -> tuple[str, ...]:  # type: ignore[override]
        if "lat" in self._params():
            return ("distance_km", "id")
        return ("name", "id")

    def get_queryset(self) -> QuerySet[Store]:
        params = self._params()
        qs = Store.objects.filter(is_active=True)
        if params.get("q"):
            q = params["q"]
            qs = qs.filter(
                Q(name__icontains=q)
                | Q(city__icontains=q)
                | Q(postcode__icontains=q)
                | Q(address__icontains=q)
            )
        if "lat" in params:
            qs = annotate_distance(qs, params["lat"], params["lng"])
        return qs


class StoreDetailView(_StoreQueryMixin, PublicReadMixin, RetrieveAPIView):
    serializer_class = StoreDetailSerializer

    def get_queryset(self) -> QuerySet[Store]:
        params = self._params()
        qs = Store.objects.filter(is_active=True).prefetch_related(
            Prefetch("opening_hours", queryset=OpeningHours.objects.order_by("weekday"))
        )
        if "lat" in params:
            qs = annotate_distance(qs, params["lat"], params["lng"])
        return qs
