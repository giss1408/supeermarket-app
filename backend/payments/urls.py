from django.urls import path

from .views import PaymentMethodListView

urlpatterns = [path("payment-methods", PaymentMethodListView.as_view())]
