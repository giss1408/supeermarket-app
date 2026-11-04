import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from catalog.models import Product
from tests.factories import CategoryFactory, ProductFactory, RetailerFactory

pytestmark = pytest.mark.django_db


def test_product_ean_nullable_but_unique_when_set():
    ProductFactory(ean="12345678")
    with pytest.raises(IntegrityError), transaction.atomic():
        ProductFactory(ean="12345678")
    ProductFactory(ean="4006381333931")


def test_two_products_without_ean_allowed():
    a = ProductFactory(ean="")
    b = ProductFactory(ean=None)
    c = ProductFactory(ean="")
    assert Product.objects.get(pk=a.pk).ean is None
    assert Product.objects.get(pk=b.pk).ean is None
    assert Product.objects.get(pk=c.pk).ean is None


@pytest.mark.parametrize("ean", ["123", "1234567", "123456789", "abcdefgh", "12345678901234"])
def test_ean_must_be_8_or_13_digits(ean):
    product = ProductFactory.build(ean=ean)
    with pytest.raises(ValidationError) as exc:
        product.full_clean()
    assert "ean" in exc.value.message_dict


def test_categories_ordered_by_sort_order_then_name():
    CategoryFactory(name="B", slug="b", sort_order=1)
    CategoryFactory(name="Z", slug="z", sort_order=0)
    CategoryFactory(name="A", slug="a", sort_order=1)
    from catalog.models import Category

    assert list(Category.objects.values_list("slug", flat=True)) == ["z", "a", "b"]


def test_two_retailers_can_share_category_slug():
    CategoryFactory(slug="fruits", retailer=RetailerFactory())
    CategoryFactory(slug="fruits", retailer=RetailerFactory())


def test_same_retailer_category_slug_rejected():
    retailer = RetailerFactory()
    CategoryFactory(slug="fruits", retailer=retailer)
    with pytest.raises(IntegrityError), transaction.atomic():
        CategoryFactory(slug="fruits", retailer=retailer)


def test_two_retailers_can_share_product_ean():
    a, b = RetailerFactory(), RetailerFactory()
    ProductFactory(ean="12345678", retailer=a, category__retailer=a)
    ProductFactory(ean="12345678", retailer=b, category__retailer=b)


def test_same_retailer_product_ean_rejected():
    retailer = RetailerFactory()
    ProductFactory(ean="12345678", retailer=retailer)
    with pytest.raises(IntegrityError), transaction.atomic():
        ProductFactory(ean="12345678", retailer=retailer)
