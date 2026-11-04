from django.urls import path

from . import views

app_name = "platform"

urlpatterns = [
    path("login/", views.PlatformLoginView.as_view(), name="login"),
    path("logout/", views.PlatformLogoutView.as_view(), name="logout"),
    path("", views.RetailerListView.as_view(), name="retailer_list"),
    path("retailers/new/", views.RetailerCreateView.as_view(), name="retailer_create"),
    path("retailers/<int:pk>/", views.RetailerDetailView.as_view(), name="retailer_detail"),
    path(
        "retailers/<int:pk>/payments/new/",
        views.PaymentCreateView.as_view(),
        name="payment_create",
    ),
    path(
        "retailers/<int:pk>/activate/",
        views.RetailerActivateView.as_view(),
        name="retailer_activate",
    ),
    path(
        "retailers/<int:pk>/suspend/",
        views.RetailerSuspendView.as_view(),
        name="retailer_suspend",
    ),
]
