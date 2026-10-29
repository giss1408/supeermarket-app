import io
import warnings

from django.core.files.base import ContentFile
from django.core.files.uploadedfile import UploadedFile
from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework.exceptions import ValidationError

MAX_UPLOAD_BYTES = 5 * 1024 * 1024
MAX_PIXELS = 40_000_000
QUALITY = 85

# Pillow format -> file extension. Anything else is rejected.
ALLOWED_FORMATS = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}


def _reject(message: str) -> ValidationError:
    return ValidationError({"file": [message]})


def _flatten_for_jpeg(img: Image.Image) -> Image.Image:
    if img.mode in ("RGB", "L"):
        return img
    if img.mode in ("RGBA", "LA", "P", "PA"):
        rgba = img.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.getchannel("A"))
        return background
    return img.convert("RGB")


def validate_and_resize(file: UploadedFile, max_edge: int = 1600) -> ContentFile:
    """Sniff, bound, orient, downscale and re-encode an uploaded image.

    Re-encoding strips EXIF/GPS metadata. The result is named ``image.<ext>`` so
    callers can read the extension; the client's filename is never used.
    """
    if file.size is None or file.size == 0:
        raise _reject("The submitted file is empty.")
    if file.size > MAX_UPLOAD_BYTES:
        raise _reject("The file is too large (maximum 5 MB).")

    file.seek(0)
    img: Image.Image
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            opened = Image.open(file)
            img = opened
            fmt = opened.format
            if fmt not in ALLOWED_FORMATS:
                raise _reject("Unsupported image type; use JPEG, PNG or WebP.")
            width, height = img.size
            if width * height > MAX_PIXELS:
                raise _reject("The image dimensions are too large.")
            img.seek(0)  # animated images: first frame only
            img.load()
            img = ImageOps.exif_transpose(img)
    except ValidationError:
        raise
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise _reject("The image dimensions are too large.") from None
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, EOFError):
        raise _reject("Upload a valid JPEG, PNG or WebP image.") from None

    assert fmt is not None
    try:
        img.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)  # never upscales
        out = io.BytesIO()
        if fmt == "JPEG":
            _flatten_for_jpeg(img).save(out, "JPEG", quality=QUALITY)
        elif fmt == "PNG":
            if img.mode not in ("1", "L", "LA", "P", "RGB", "RGBA"):
                img = img.convert("RGBA" if "A" in img.getbands() else "RGB")
            img.save(out, "PNG", optimize=True)
        else:
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA" if img.has_transparency_data else "RGB")
            img.save(out, "WEBP", quality=QUALITY)
    except (OSError, SyntaxError, ValueError, KeyError, EOFError):
        # Exotic modes (e.g. I;16) that Pillow cannot convert or encode are a client error.
        raise _reject("Upload a valid JPEG, PNG or WebP image.") from None
    return ContentFile(out.getvalue(), name=f"image.{ALLOWED_FORMATS[fmt]}")
