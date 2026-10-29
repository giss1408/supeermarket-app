import pytest
from rest_framework import serializers
from rest_framework.generics import ListAPIView

from accounts.models import User
from common.pagination import DefaultCursorPagination


def test_defaults():
    assert DefaultCursorPagination.page_size == 20
    assert DefaultCursorPagination.ordering == "-created_at"


class UserSer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "email"]


class UserList(ListAPIView):
    authentication_classes: list = []
    permission_classes: list = []
    queryset = User.objects.all()
    serializer_class = UserSer
    ordering = "id"


@pytest.fixture
def view():
    from rest_framework.test import APIRequestFactory

    def call():
        return UserList.as_view()(APIRequestFactory().get("/"))

    return call


@pytest.mark.django_db
def test_empty_table(view):
    r = view()
    r.render()
    assert r.status_code == 200
    assert r.data["results"] == []
    assert r.data["next"] is None
    assert r.data["previous"] is None


@pytest.mark.django_db
def test_pages_of_20(view):
    for i in range(25):
        User.objects.create_user(f"u{i}@example.com")
    r = view()
    assert len(r.data["results"]) == 20
    assert r.data["next"] is not None
    assert r.data["previous"] is None
