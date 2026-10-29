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
