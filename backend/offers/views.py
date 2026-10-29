from django.db.models import Count, Prefetch, Q, QuerySet
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework.generics import ListAPIView, RetrieveAPIView, get_object_or_404

from common.views import PublicReadMixin

from .models import Flyer, Offer
from .serializers import (
    FlyerDetailSerializer,
    FlyerListSerializer,
    OfferQuerySerializer,
    OfferSerializer,
)


def published_flyers() -> QuerySet[Flyer]:
    return Flyer.objects.filter(status=Flyer.Status.PUBLISHED)


class FlyerListView(PublicReadMixin, ListAPIView):
    serializer_class = FlyerListSerializer
    ordering = ("-valid_from", "-id")

    def get_queryset(self) -> QuerySet[Flyer]:
        return published_flyers().annotate(offer_count=Count("offers"))


def _with_offers(qs: QuerySet[Flyer]) -> QuerySet[Flyer]:
    offers = Offer.objects.select_related("product__category").order_by("sort_order", "id")
    return qs.prefetch_related(Prefetch("offers", queryset=offers))


class FlyerDetailView(PublicReadMixin, RetrieveAPIView):
    serializer_class = FlyerDetailSerializer

    def get_queryset(self) -> QuerySet[Flyer]:
        return _with_offers(published_flyers())


class CurrentFlyerView(PublicReadMixin, RetrieveAPIView):
    serializer_class = FlyerDetailSerializer

    def get_object(self) -> Flyer:
        today = timezone.localdate()
        qs = _with_offers(
            published_flyers().filter(valid_from__lte=today, valid_to__gte=today)
        ).order_by("-valid_from", "-id")
        return get_object_or_404(qs[:1])


@extend_schema(parameters=[OfferQuerySerializer])
class OfferListView(PublicReadMixin, ListAPIView):
    serializer_class = OfferSerializer
    ordering = ("sort_order", "id")

    def get_queryset(self) -> QuerySet[Offer]:
        params = OfferQuerySerializer(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        data = params.validated_data
        qs = Offer.objects.filter(flyer__status=Flyer.Status.PUBLISHED).select_related(
            "product__category"
        )
        if "category" in data:
            qs = qs.filter(product__category__slug=data["category"])
        if "flyer" in data:
            qs = qs.filter(flyer_id=data["flyer"])
        if data.get("q"):
            qs = qs.filter(
                Q(product__name__icontains=data["q"]) | Q(badge_text__icontains=data["q"])
            )
        return qs
