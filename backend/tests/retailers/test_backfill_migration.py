import datetime
from decimal import Decimal

import pytest
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.utils import timezone

BEFORE = [
    ("accounts", "0003_retailer_and_roles"),
    ("retailers", "0001_initial"),
    ("catalog", "0002_category_retailer_product_retailer"),
    ("stores", "0002_store_retailer"),
    ("offers", "0003_flyer_retailer"),
    ("payments", "0003_paymentmethod_retailer"),
]
CONTENT = [
    ("catalog", "Category"),
    ("catalog", "Product"),
    ("stores", "Store"),
    ("offers", "Flyer"),
    ("payments", "PaymentMethod"),
]


@pytest.fixture
def migrator():
    executor = MigrationExecutor(connection)
    yield executor
    executor = MigrationExecutor(connection)
    executor.migrate(executor.loader.graph.leaf_nodes())


def _migrate(targets):
    executor = MigrationExecutor(connection)
    state = executor.migrate(targets)
    return state.apps


def _forward():
    return _migrate(MigrationExecutor(connection).loader.graph.leaf_nodes())


@pytest.mark.django_db(transaction=True)
def test_backfill_assigns_default_retailer(migrator):
    apps = _migrate(BEFORE)
    user = apps.get_model("accounts", "User").objects.create(
        email="old-staff@example.com", name="Old", role="retailer_staff", password="x"
    )
    category = apps.get_model("catalog", "Category").objects.create(name="Fruits", slug="fruits")
    apps.get_model("catalog", "Product").objects.create(
        name="Apple", category=category, ean="12345678"
    )
    apps.get_model("stores", "Store").objects.create(
        name="S", address="a", city="c", postcode="1", latitude=Decimal(1), longitude=Decimal(1)
    )
    today = datetime.date.today()
    apps.get_model("offers", "Flyer").objects.create(
        title="F", valid_from=today, valid_to=today, status="published"
    )
    apps.get_model("payments", "PaymentMethod").objects.create(
        provider="wave", phone_number="+2250700000001"
    )

    before = timezone.now()
    apps = _forward()

    retailers = list(apps.get_model("retailers", "Retailer").objects.all())
    assert len(retailers) == 1
    default = retailers[0]
    assert (default.slug, default.status, default.name) == ("default", "active", "Default retailer")
    sub = apps.get_model("retailers", "Subscription").objects.get(retailer=default)
    expected = before + datetime.timedelta(days=365)
    assert abs((sub.ends_at - expected).total_seconds()) < 120
    for app_label, model in CONTENT:
        rows = apps.get_model(app_label, model).objects.all()
        assert rows.exists()
        assert all(row.retailer_id == default.pk for row in rows), model
    user = apps.get_model("accounts", "User").objects.get(pk=user.pk)
    assert user.role == "retailer_staff"
    assert user.retailer_id == default.pk


@pytest.mark.django_db(transaction=True)
def test_backfill_creates_nothing_on_empty_database(migrator):
    _migrate(BEFORE)
    apps = _forward()
    assert not apps.get_model("retailers", "Retailer").objects.exists()
    assert not apps.get_model("retailers", "Subscription").objects.exists()
