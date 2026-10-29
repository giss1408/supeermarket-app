from django.utils import translation
from drf_spectacular.utils import extend_schema
from drf_spectacular.views import SpectacularAPIView
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class PublicReadMixin(APIView):
    # Anonymous, read-only access. No authentication, so a stale Bearer token never 401s.
    #
    # Views built on this expose only GET handlers, so other methods yield a standard 405.
    # (Adding ``ReadOnly`` here would turn that 405 into a 403, because permissions run first.)
    # Kept as a comment, not a docstring: spectacular copies docstrings into the OpenAPI spec.

    authentication_classes: list = []
    permission_classes = [AllowAny]


class EnglishSchemaView(SpectacularAPIView):
    # Kept as a comment: the schema is always rendered in English whatever the request language.
    @extend_schema(exclude=True)
    def get(self, request: Request, *args: object, **kwargs: object) -> Response:
        with translation.override("en"):
            return super().get(request, *args, **kwargs)
