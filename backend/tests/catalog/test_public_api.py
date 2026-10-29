import pytest
from rest_framework.test import APIClient

from tests.factories import CategoryFactory

pytestmark = pytest.mark.django_db


def test_categories_ordered_by_sort_order_then_id():
    b = CategoryFactory(name="B", slug="b", sort_order=2)
    a = CategoryFactory(name="A", slug="a", sort_order=1)
    c = CategoryFactory(name="C", slug="c", sort_order=2)
    resp = APIClient().get("/api/v1/categories")
    assert resp.status_code == 200
    assert [x["id"] for x in resp.data["results"]] == [a.id, b.id, c.id]
    assert set(resp.data["results"][0]) == {"id", "name", "slug"}


def test_categories_page_size_is_100():
    from catalog.views import CategoryPagination

    assert CategoryPagination.page_size == 100
