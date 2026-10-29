from rest_framework.generics import ListAPIView

from common.pagination import DefaultCursorPagination
from common.views import PublicReadMixin

from .models import Category
from .serializers import CategorySerializer


class CategoryPagination(DefaultCursorPagination):
    page_size = 100


class CategoryListView(PublicReadMixin, ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    pagination_class = CategoryPagination
    ordering = ("sort_order", "id")
