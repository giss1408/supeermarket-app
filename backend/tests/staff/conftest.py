import pytest
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
