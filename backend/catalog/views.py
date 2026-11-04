from django.db.models import QuerySet
from rest_framework.generics import ListAPIView

from common.pagination import DefaultCursorPagination
from common.views import PublicReadMixin, active_retailer_only

from .models import Category
from .serializers import CategorySerializer


class CategoryPagination(DefaultCursorPagination):
    page_size = 100


class CategoryListView(PublicReadMixin, ListAPIView):
    serializer_class = CategorySerializer
    pagination_class = CategoryPagination
    ordering = ("sort_order", "id")

    def get_queryset(self) -> QuerySet[Category]:
        return active_retailer_only(Category.objects.all())
