import datetime
from decimal import Decimal

import factory
from django.contrib.auth import get_user_model

PASSWORD = "pass12345!word"


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
    role = "staff"


class CategoryFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "catalog.Category"

    name = factory.Sequence(lambda n: f"Category {n}")
    slug = factory.Sequence(lambda n: f"category-{n}")


class ProductFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "catalog.Product"

    name = factory.Sequence(lambda n: f"Product {n}")
    category = factory.SubFactory(CategoryFactory)
    unit = "1 kg"


class FlyerFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = "offers.Flyer"

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
