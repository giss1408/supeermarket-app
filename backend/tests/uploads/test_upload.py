import io
import os
import re
import struct
import warnings
import zlib

import pytest
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.exceptions import ValidationError

from uploads.validators import MAX_UPLOAD_BYTES, validate_and_resize

from .conftest import make_image

pytestmark = pytest.mark.django_db

URL = "/api/v1/staff/uploads/image"
NAME_RE = re.compile(r"^uploads/[0-9a-f]{32}\.(jpg|png|webp)$")


def post(client, content, name="a.png", ctype="image/png", field="file"):
    return client.post(URL, {field: SimpleUploadedFile(name, content, ctype)}, format="multipart")


def stored(name) -> Image.Image:
    with default_storage.open(name) as f:
        img = Image.open(io.BytesIO(f.read()))
        img.load()
        return img


def assert_file_error(resp):
    assert resp.status_code == 400
    assert resp.json()["code"] == "validation_error"
    assert "file" in resp.json()["fields"]


@pytest.mark.parametrize(("fmt", "ext"), [("JPEG", "jpg"), ("PNG", "png"), ("WEBP", "webp")])
def test_valid_jpeg_png_webp_accepted(staff_client, fmt, ext):
    resp = post(staff_client, make_image(fmt), name=f"x.{ext}")
    assert resp.status_code == 201
    body = resp.json()
    assert body["url"]
    assert NAME_RE.match(body["name"])
    assert body["name"].endswith(f".{ext}")
    assert default_storage.exists(body["name"])
    assert stored(body["name"]).format == fmt


def test_upload_url_is_absolute(staff_client):
    resp = post(staff_client, make_image("PNG"))
    assert resp.json()["url"].startswith("http://testserver/")
    assert resp.json()["url"].endswith(resp.json()["name"])


def test_oversize_file_rejected(staff_client):
    big = os.urandom(MAX_UPLOAD_BYTES + 1)
    assert_file_error(post(staff_client, big))


def test_just_under_limit_passes_size_check():
    img = Image.frombytes("RGB", (1250, 1250), os.urandom(1250 * 1250 * 3))
    buf = io.BytesIO()
    img.save(buf, "PNG", compress_level=0)
    data = buf.getvalue()
    assert 4_000_000 < len(data) < MAX_UPLOAD_BYTES
    out = validate_and_resize(SimpleUploadedFile("a.png", data, "image/png"))
    assert isinstance(out, ContentFile)


def test_text_file_renamed_png_rejected(staff_client):
    assert_file_error(post(staff_client, b"hello", name="x.png", ctype="image/png"))


def test_svg_rejected(staff_client):
    svg = b'<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>'
    assert_file_error(post(staff_client, svg, name="x.png", ctype="image/svg+xml"))


@pytest.mark.parametrize("fmt", ["GIF", "BMP"])
def test_gif_and_bmp_rejected(staff_client, fmt):
    assert_file_error(post(staff_client, make_image(fmt), name="x.png", ctype="image/png"))


def test_corrupt_truncated_image_rejected(staff_client):
    data = make_image("PNG", size=(200, 200))
    assert_file_error(post(staff_client, data[: len(data) // 2]))


def test_corrupt_truncated_jpeg_rejected(staff_client):
    img = Image.frombytes("RGB", (300, 300), os.urandom(270000))
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    data = buf.getvalue()
    assert_file_error(post(staff_client, data[: len(data) // 2], name="a.jpg", ctype="image/jpeg"))


def test_empty_file_rejected(staff_client):
    assert_file_error(post(staff_client, b""))


def test_large_image_resized_to_max_edge(staff_client):
    resp = post(staff_client, make_image("JPEG", size=(4000, 2000)), name="a.jpg")
    assert resp.status_code == 201
    assert stored(resp.json()["name"]).size == (1600, 800)


def test_small_image_not_upscaled(staff_client):
    resp = post(staff_client, make_image("PNG", size=(100, 50)))
    assert stored(resp.json()["name"]).size == (100, 50)


def test_exif_orientation_applied_and_metadata_stripped(staff_client):
    img = Image.new("RGB", (60, 20), (10, 200, 10))
    exif = Image.Exif()
    exif[0x0112] = 6  # rotate 90 CW to display
    exif[0x010F] = "SecretCamCo"
    gps = exif.get_ifd(0x8825)
    gps[1] = "N"
    buf = io.BytesIO()
    img.save(buf, "JPEG", exif=exif)
    assert Image.open(io.BytesIO(buf.getvalue())).getexif()[0x010F] == "SecretCamCo"

    resp = post(staff_client, buf.getvalue(), name="a.jpg", ctype="image/jpeg")
    assert resp.status_code == 201
    out = stored(resp.json()["name"])
    assert out.size == (20, 60)
    assert len(out.getexif()) == 0
    assert "exif" not in out.info
    with default_storage.open(resp.json()["name"]) as f:
        assert b"SecretCamCo" not in f.read()


def test_rgba_png_to_jpeg_not_applicable_png_keeps_alpha(staff_client):
    resp = post(staff_client, make_image("PNG", mode="RGBA"))
    assert stored(resp.json()["name"]).mode == "RGBA"


def png_declaring(width: int, height: int) -> bytes:
    """Minimal PNG with a VALID IHDR CRC declaring the size; no pixel data (IDAT is empty)."""

    def chunk(kind: bytes, body: bytes) -> bytes:
        crc = zlib.crc32(kind + body)
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", b"") + chunk(b"IEND", b"")


def file_message(resp) -> str:
    return " ".join(resp.json()["fields"]["file"])


@pytest.mark.parametrize("size", [(8000, 6000), (10000, 10000)])  # 48 MP gate, 100 MP Pillow bomb
def test_pixel_bomb_rejected(staff_client, size):
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        resp = post(staff_client, png_declaring(*size))
    assert_file_error(resp)
    assert "dimensions are too large" in file_message(resp)


def test_dimensions_just_under_pixel_limit_pass_the_gate(staff_client):
    # 36 MP declared, no pixel data: not rejected as too large (fails later as corrupt).
    resp = post(staff_client, png_declaring(6000, 6000))
    assert_file_error(resp)
    assert "too large" not in file_message(resp)


def test_decompression_bomb_error_is_400(monkeypatch):
    monkeypatch.setattr(Image, "MAX_IMAGE_PIXELS", 100)
    data = make_image("PNG", size=(100, 100))
    with pytest.raises(ValidationError) as exc:
        validate_and_resize(SimpleUploadedFile("a.png", data, "image/png"))
    assert "file" in exc.value.detail


@pytest.mark.parametrize("name", ["../../evil.png", "we ird\x00;name.jpg", "/etc/passwd", "ü.png"])
def test_client_filename_ignored(staff_client, name):
    resp = post(staff_client, make_image("PNG"), name=name)
    assert resp.status_code == 201
    assert NAME_RE.match(resp.json()["name"])
    assert "evil" not in resp.json()["url"]


def test_customer_forbidden(customer_client):
    assert post(customer_client, make_image("PNG")).status_code == 403


def test_anonymous_unauthorized(anon_client):
    resp = post(anon_client, make_image("PNG"))
    assert resp.status_code == 401
    assert set(resp.json()) >= {"code", "detail", "fields"}


def test_missing_file_returns_400_field_error(staff_client):
    resp = staff_client.post(URL, {}, format="multipart")
    assert_file_error(resp)


def test_wrong_field_name_returns_400(staff_client):
    assert_file_error(post(staff_client, make_image("PNG"), field="image"))


def test_file_field_as_plain_text_returns_400(staff_client):
    resp = staff_client.post(URL, {"file": "not a file"}, format="multipart")
    assert_file_error(resp)


def test_non_multipart_request_returns_415_standard_shape(staff_client):
    resp = staff_client.post(URL, {"file": "x"}, format="json")
    assert resp.status_code == 415
    assert set(resp.json()) >= {"code", "detail", "fields"}


def test_animated_png_flattened_to_first_frame(staff_client):
    frames = [Image.new("RGB", (30, 30), c) for c in ((255, 0, 0), (0, 0, 255))]
    buf = io.BytesIO()
    frames[0].save(buf, "PNG", save_all=True, append_images=frames[1:])
    resp = post(staff_client, buf.getvalue())
    assert resp.status_code == 201
    out = stored(resp.json()["name"])
    assert getattr(out, "n_frames", 1) == 1


def test_animated_webp_flattened_to_first_frame(staff_client):
    frames = [Image.new("RGB", (30, 30), c) for c in ((255, 0, 0), (0, 0, 255))]
    buf = io.BytesIO()
    frames[0].save(buf, "WEBP", save_all=True, append_images=frames[1:], duration=100)
    resp = post(staff_client, buf.getvalue(), name="a.webp", ctype="image/webp")
    assert resp.status_code == 201
    out = stored(resp.json()["name"])
    assert getattr(out, "n_frames", 1) == 1


def test_validate_and_resize_custom_max_edge():
    data = make_image("PNG", size=(300, 100))
    out = validate_and_resize(SimpleUploadedFile("a.png", data, "image/png"), max_edge=150)
    assert Image.open(io.BytesIO(out.read())).size == (150, 50)
