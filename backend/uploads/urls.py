from django.urls import path

from .views import ImageUploadView

urlpatterns = [path("uploads/image", ImageUploadView.as_view(), name="staff-upload-image")]
