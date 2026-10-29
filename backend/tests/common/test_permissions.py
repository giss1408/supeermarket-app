from unittest import mock

from rest_framework.test import APIRequestFactory

from common.permissions import IsOwner, IsStaff, ReadOnly

factory = APIRequestFactory()


def req(method="get", **user_attrs):
    request = getattr(factory, method)("/")
    request.user = mock.Mock(**user_attrs)
    return request


def test_is_staff_denies_anonymous():
    assert not IsStaff().has_permission(req(is_authenticated=False, role="staff"), None)


def test_is_staff_denies_customer():
    assert not IsStaff().has_permission(req(is_authenticated=True, role="customer"), None)


def test_is_staff_denies_user_without_role_field():
    user = mock.Mock(spec=["is_authenticated"], is_authenticated=True)
    request = factory.get("/")
    request.user = user
    assert not IsStaff().has_permission(request, None)


def test_is_staff_allows_staff():
    assert IsStaff().has_permission(req(is_authenticated=True, role="staff"), None)


def test_is_owner():
    request = req(id=5)
    assert IsOwner().has_object_permission(request, None, mock.Mock(user_id=5))
    assert not IsOwner().has_object_permission(request, None, mock.Mock(user_id=6))


def test_read_only():
    assert ReadOnly().has_permission(req("get"), None)
    assert ReadOnly().has_permission(req("head"), None)
    assert ReadOnly().has_permission(req("options"), None)
    assert not ReadOnly().has_permission(req("post"), None)
    assert not ReadOnly().has_permission(req("delete"), None)
