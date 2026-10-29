import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from shopping.models import ListItem, ShoppingList
from tests.factories import ListItemFactory, ProductFactory, ShoppingListFactory

pytestmark = pytest.mark.django_db


def test_item_requires_product_or_text():
    lst = ShoppingListFactory()
    with pytest.raises(IntegrityError), transaction.atomic():
        ListItem.objects.create(list=lst, text="")
    assert ListItem.objects.create(list=lst, text="milk").pk
    assert ListItem.objects.create(list=lst, product=ProductFactory(), text="").pk


def test_quantity_check_constraint_at_db_level():
    lst = ShoppingListFactory()
    with pytest.raises(IntegrityError), transaction.atomic():
        ListItem.objects.create(list=lst, text="x", quantity=0)


def test_quantity_validators():
    item = ListItem(list=ShoppingListFactory(), text="x", quantity=1000)
    with pytest.raises(ValidationError):
        item.full_clean()
    item.quantity = 0
    with pytest.raises(ValidationError):
        item.full_clean()
    item.quantity = 999
    item.full_clean()


def _updated(lst):
    return ShoppingList.objects.get(pk=lst.pk).updated_at


def test_item_change_bumps_list_updated_at():
    lst = ShoppingListFactory()
    ShoppingList.objects.filter(pk=lst.pk).update(updated_at=timezone.now().replace(year=2020))
    old = _updated(lst)
    item = ListItem.objects.create(list=lst, text="a")
    created = _updated(lst)
    assert created > old
    ShoppingList.objects.filter(pk=lst.pk).update(updated_at=old)
    item.checked = True
    item.save()
    assert _updated(lst) > old
    ShoppingList.objects.filter(pk=lst.pk).update(updated_at=old)
    item.delete()
    assert _updated(lst) > old


def test_deleting_list_deletes_items():
    item = ListItemFactory()
    item.list.delete()
    assert not ListItem.objects.filter(pk=item.pk).exists()


def test_product_deletion_removes_item_from_list():
    product = ProductFactory()
    item = ListItemFactory(product=product, text="")
    other = ListItemFactory(list=item.list, text="keep")
    product.delete()
    assert not ListItem.objects.filter(pk=item.pk).exists()
    assert ListItem.objects.filter(pk=other.pk).exists()
