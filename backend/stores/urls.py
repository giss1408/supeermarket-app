from django.urls import path

from .views import StoreDetailView, StoreListView

urlpatterns = [
    path("stores", StoreListView.as_view()),
    path("stores/<int:pk>", StoreDetailView.as_view()),
]
