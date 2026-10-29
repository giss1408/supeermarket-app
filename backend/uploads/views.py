import uuid

from django.core.files.storage import default_storage
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.parsers import MultiPartParser
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from common.permissions import IsStaff

from .validators import validate_and_resize


class ImageUploadSerializer(serializers.Serializer):
    file = serializers.FileField(help_text="JPEG, PNG or WebP image, max 5 MB.")


UploadResultSerializer = inline_serializer(
    "ImageUploadResult",
    {"url": serializers.URLField(), "name": serializers.CharField()},
)


class ImageUploadView(APIView):
    permission_classes = [IsStaff]
    parser_classes = [MultiPartParser]

    @extend_schema(
        request={"multipart/form-data": ImageUploadSerializer},
        responses={201: UploadResultSerializer, 400: OpenApiResponse(description="Invalid file")},
    )
    def post(self, request: Request) -> Response:
        serializer = ImageUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        content = validate_and_resize(serializer.validated_data["file"])
        ext = str(content.name).rsplit(".", 1)[-1]
        name = default_storage.save(f"uploads/{uuid.uuid4().hex}.{ext}", content)
        url = default_storage.url(name)
        if not url.startswith(("http://", "https://")):
            url = request.build_absolute_uri(url)
        return Response({"url": url, "name": name}, status=status.HTTP_201_CREATED)
