from django.db.models import QuerySet
from rest_framework.generics import ListAPIView
from rest_framework.throttling import BaseThrottle, ScopedRateThrottle

from common.pagination import DefaultCursorPagination
from common.views import PublicReadMixin
from staff.views import StaffViewSet

from .models import PaymentMethod
from .serializers import PaymentMethodSerializer, StaffPaymentMethodSerializer


class PaymentMethodPagination(DefaultCursorPagination):
    page_size = 100


class PaymentMethodListView(PublicReadMixin, ListAPIView):
    serializer_class = PaymentMethodSerializer
    pagination_class = PaymentMethodPagination
    ordering = ("provider", "id")

    def get_queryset(self) -> QuerySet[PaymentMethod]:
        return PaymentMethod.objects.filter(is_active=True)


class PaymentMethodStaffViewSet(StaffViewSet):
    queryset = PaymentMethod.objects.all()
    serializer_class = StaffPaymentMethodSerializer
    pagination_class = PaymentMethodPagination
    ordering = ("provider", "id")
    http_method_names = ["get", "post", "patch", "head", "options"]
    throttle_scope = "staff_sensitive"

    def get_throttles(self) -> list[BaseThrottle]:
        # Only the writes that ask for the password are throttled (every attempt counts).
        if self.action in ("create", "partial_update"):
            return [ScopedRateThrottle()]
        return []
