from django.contrib import admin
from django.http import HttpRequest, JsonResponse
from django.urls import include, path


def healthz(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("healthz", healthz),
    path("api/v1/", include("accounts.urls")),
    path("api/v1/", include("catalog.urls")),
    path("api/v1/", include("offers.urls")),
    path("api/v1/", include("stores.urls")),
    path("admin/", admin.site.urls),
]
