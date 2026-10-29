import re

from django.core.files.storage import default_storage
from rest_framework import serializers

UPLOAD_NAME_RE = re.compile(r"uploads/[0-9a-f]{32}\.(jpg|png|webp)")


class UploadedImageNameField(serializers.CharField):
    """Storage key returned by the upload endpoint; only such keys are accepted.

    The strict pattern plus an existence check stop staff from pointing an
    ImageField at arbitrary storage keys (other files, ``../`` paths).
    """

    def __init__(self, **kwargs):
        kwargs.setdefault("required", False)
        kwargs.setdefault("allow_null", True)
        kwargs.setdefault("write_only", True)
        kwargs["trim_whitespace"] = False
        super().__init__(**kwargs)

    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        if not UPLOAD_NAME_RE.fullmatch(value):
            raise serializers.ValidationError("Not a valid uploaded image name.")
        if not default_storage.exists(value):
            raise serializers.ValidationError("No uploaded image with this name.")
        return value
