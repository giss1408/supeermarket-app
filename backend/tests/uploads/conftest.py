import io

import pytest
from PIL import Image
from rest_framework.test import APIClient

from tests.factories import StaffFactory, UserFactory


@pytest.fixture
def staff_client():
    client = APIClient()
    client.force_authenticate(StaffFactory())
    return client


@pytest.fixture
def customer_client():
    client = APIClient()
    client.force_authenticate(UserFactory())
    return client


@pytest.fixture
def anon_client():
    return APIClient()


def make_image(fmt="JPEG", size=(40, 30), mode="RGB", **save_kwargs) -> bytes:
    buf = io.BytesIO()
    Image.new(mode, size, (200, 30, 30) if mode == "RGB" else None).save(buf, fmt, **save_kwargs)
    return buf.getvalue()
