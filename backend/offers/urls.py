from django.urls import path

from .views import CurrentFlyerView, FlyerDetailView, FlyerListView, OfferListView

urlpatterns = [
    path("flyers", FlyerListView.as_view()),
    # Must stay before the <int:pk> route.
    path("flyers/current", CurrentFlyerView.as_view()),
    path("flyers/<int:pk>", FlyerDetailView.as_view()),
    path("offers", OfferListView.as_view()),
]
