from django.db.models import Count, QuerySet
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from common.pagination import DefaultCursorPagination

from .models import ListItem, ShoppingList
from .serializers import (
    ListItemResponseSerializer,
    ListItemSerializer,
    ShoppingListDetailSerializer,
    ShoppingListSerializer,
    UpdatedSinceSerializer,
)


class OwnedListMixin(APIView):
    permission_classes = [IsAuthenticated]

    def get_queryset(self) -> QuerySet[ShoppingList]:
        return ShoppingList.objects.filter(user=self.request.user)  # type: ignore[misc]


@extend_schema_view(get=extend_schema(parameters=[UpdatedSinceSerializer]))
class ShoppingListCollectionView(OwnedListMixin, generics.ListCreateAPIView):
    pagination_class = DefaultCursorPagination
    ordering = ("-updated_at", "-id")
    http_method_names = ["get", "post", "head", "options"]

    def get_serializer_class(self):  # type: ignore[no-untyped-def]
        if self.request.method == "POST":
            return ShoppingListDetailSerializer
        return ShoppingListSerializer

    def get_queryset(self) -> QuerySet[ShoppingList]:
        qs = super().get_queryset().annotate(item_count=Count("items"))
        params = UpdatedSinceSerializer(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        since = params.validated_data.get("updated_since")
        if since is not None:
            qs = qs.filter(updated_at__gt=since)
        return qs

    def perform_create(self, serializer: ShoppingListDetailSerializer) -> None:  # type: ignore[override]
        serializer.save(user=self.request.user)


class ShoppingListDetailView(OwnedListMixin, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ShoppingListDetailSerializer
    http_method_names = ["get", "patch", "delete", "head", "options"]


@extend_schema(request=ListItemSerializer, responses={201: ListItemResponseSerializer})
class ListItemCreateView(OwnedListMixin, generics.CreateAPIView):
    serializer_class = ListItemSerializer

    def perform_create(self, serializer: ListItemSerializer) -> None:  # type: ignore[override]
        shopping_list = get_object_or_404(self.get_queryset(), pk=self.kwargs["list_id"])
        serializer.save(list=shopping_list)


@extend_schema_view(
    patch=extend_schema(request=ListItemSerializer, responses=ListItemResponseSerializer)
)
class ListItemDetailView(OwnedListMixin, generics.UpdateAPIView, generics.DestroyAPIView):
    serializer_class = ListItemSerializer
    http_method_names = ["patch", "delete", "options"]

    def get_object(self) -> ListItem:
        shopping_list = get_object_or_404(self.get_queryset(), pk=self.kwargs["list_id"])
        return get_object_or_404(
            shopping_list.items.select_related("product"), pk=self.kwargs["item_id"]
        )
