import datetime
from decimal import Decimal

import factory
from django.contrib.auth import get_user_model

PASSWORD = "pass12345!word"


def _attach_subscription(retailer, days):
    from django.utils import timezone

    from retailers.models import Subscription

    now = timezone.now()
    Subscription.objects.update_or_create(
        retailer=retailer,
        defaults={"starts_at": now, "ends_at": now + datetime.timedelta(days=days)},
    )


class RetailerFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "retailers.Retailer"
        skip_postgeneration_save = True

    name = factory.Sequence(lambda n: f"Retailer {n}")
    slug = factory.Sequence(lambda n: f"retailer-{n}")
    status = "active"

    @factory.post_generation
    def subscription(self, create, extracted, **kwargs):
        if create:
            _attach_subscription(self, 30)


def default_retailer():
    """Shared active retailer (subscription +365 days) used by factories as the default tenant."""
    from retailers.models import Retailer

    retailer, created = Retailer.objects.get_or_create(
        slug="test-retailer", defaults={"name": "Test Retailer", "status": "active"}
    )
    if created:
        _attach_subscription(retailer, 365)
    return retailer


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = get_user_model()
        skip_postgeneration_save = True

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    name = factory.Sequence(lambda n: f"User {n}")
    role = "customer"

    @classmethod
    def _create(cls, model_class, *args, **kwargs):
        password = kwargs.pop("password", PASSWORD)
        return model_class.objects.create_user(password=password, **kwargs)


class StaffFactory(UserFactory):
    email = factory.Sequence(lambda n: f"staff{n}@example.com")
    role = "retailer_staff"
    retailer = factory.LazyFunction(default_retailer)


class PlatformAdminFactory(UserFactory):
    email = factory.Sequence(lambda n: f"admin{n}@example.com")
    role = "platform_admin"


class CategoryFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "catalog.Category"

    retailer = factory.LazyFunction(default_retailer)
    name = factory.Sequence(lambda n: f"Category {n}")
    slug = factory.Sequence(lambda n: f"category-{n}")


class ProductFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "catalog.Product"

    retailer = factory.LazyFunction(default_retailer)
    name = factory.Sequence(lambda n: f"Product {n}")
    category = factory.SubFactory(CategoryFactory, retailer=factory.SelfAttribute("..retailer"))
    unit = "1 kg"


class FlyerFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "offers.Flyer"

    retailer = factory.LazyFunction(default_retailer)
    title = factory.Sequence(lambda n: f"Flyer {n}")
    valid_from = factory.LazyFunction(datetime.date.today)
    valid_to = factory.LazyFunction(lambda: datetime.date.today() + datetime.timedelta(days=6))
    status = "draft"


class OfferFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "offers.Offer"

    flyer = factory.SubFactory(FlyerFactory)
    product = factory.SubFactory(ProductFactory)
    price = Decimal("1.99")


class StoreFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "stores.Store"

    retailer = factory.LazyFunction(default_retailer)
    name = factory.Sequence(lambda n: f"Store {n}")
    address = "1 Main Street"
    city = "Springfield"
    postcode = "12345"
    latitude = Decimal("50.737400")
    longitude = Decimal("7.098200")


class OpeningHoursFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "stores.OpeningHours"

    store = factory.SubFactory(StoreFactory)
    weekday = 0
    opens = datetime.time(8, 0)
    closes = datetime.time(20, 0)


class ShoppingListFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "shopping.ShoppingList"

    user = factory.SubFactory(UserFactory)
    name = factory.Sequence(lambda n: f"List {n}")


class ListItemFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "shopping.ListItem"

    list = factory.SubFactory(ShoppingListFactory)
    text = factory.Sequence(lambda n: f"Item {n}")
    quantity = 1


class PaymentMethodFactory(factory.django.DjangoModelFactory):
    """Provider is unique per retailer: pass it explicitly (default wave) or use ``create_all``."""

    class Meta:
        model = "payments.PaymentMethod"

    retailer = factory.LazyFunction(default_retailer)
    provider = "wave"
    phone_number = "+2250700000001"
    display_name = ""
    instructions = ""
    is_active = True

    @classmethod
    def create_all(cls, **kwargs):
        numbers = {
            "wave": "+2250700000001",
            "orange_money": "+2250500000002",
            "mtn_momo": "+2250100000003",
        }
        return [cls.create(provider=p, **{"phone_number": n, **kwargs}) for p, n in numbers.items()]
