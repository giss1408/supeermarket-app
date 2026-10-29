from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import HttpRequest, JsonResponse
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView
from rest_framework.permissions import AllowAny

import common.openapi  # noqa: F401  (registers the bearerAuth scheme extension)


handler400 = "common.handlers.handler400"
handler403 = "common.handlers.handler403"
handler404 = "common.handlers.handler404"
handler500 = "common.handlers.handler500"


def healthz(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path(
        "api/schema/",
        SpectacularAPIView.as_view(authentication_classes=[], permission_classes=[AllowAny]),
        name="schema",
    ),
    path("healthz", healthz),
    path("api/v1/", include("accounts.urls")),
    path("api/v1/", include("catalog.urls")),
    path("api/v1/", include("offers.urls")),
    path("api/v1/", include("stores.urls")),
    path("api/v1/", include("shopping.urls")),
    path("api/v1/staff/", include("staff.urls")),
    path("api/v1/staff/", include("uploads.urls")),
    path("admin/", admin.site.urls),
]

# Local media is served by Django only in development (prod uses S3 or a real web server).
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
