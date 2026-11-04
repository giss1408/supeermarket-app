import pytest
from django.db.models import ProtectedError

from accounts.models import User
from tests.factories import PlatformAdminFactory, RetailerFactory, StaffFactory

pytestmark = pytest.mark.django_db


def test_superuser_is_platform_admin():
    admin = User.objects.create_superuser("root@example.com", "pass12345!word")
    assert admin.role == User.Role.PLATFORM_ADMIN
    assert admin.retailer is None


def test_deleting_retailer_with_users_is_protected():
    retailer = RetailerFactory()
    StaffFactory(retailer=retailer)
    with pytest.raises(ProtectedError):
        retailer.delete()


def test_platform_admin_factory_has_no_retailer():
    assert PlatformAdminFactory().retailer is None
