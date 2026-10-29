from django.urls import path

from .views import (
    ListItemCreateView,
    ListItemDetailView,
    ShoppingListCollectionView,
    ShoppingListDetailView,
)

urlpatterns = [
    path("lists", ShoppingListCollectionView.as_view()),
    path("lists/<int:pk>", ShoppingListDetailView.as_view()),
    path("lists/<int:list_id>/items", ListItemCreateView.as_view()),
    path("lists/<int:list_id>/items/<int:item_id>", ListItemDetailView.as_view()),
]
