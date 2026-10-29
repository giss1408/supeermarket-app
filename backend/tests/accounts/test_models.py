import re

import pytest
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction

from accounts.models import LoyaltyCard, generate_card_number
from tests.factories import StaffFactory, UserFactory

pytestmark = pytest.mark.django_db
User = get_user_model()


def test_customer_gets_card_with_13_digits():
    user = UserFactory()
    assert re.fullmatch(r"\d{13}", user.card.number)


def test_generate_card_number_is_13_digits():
    assert re.fullmatch(r"\d{13}", generate_card_number())


def test_generate_card_number_retries_on_collision(monkeypatch):
    user = UserFactory()
    taken = user.card.number
    values = iter([int(taken), 5])
    monkeypatch.setattr("accounts.models.secrets.randbelow", lambda n: next(values))
    assert generate_card_number() == "0000000000005"


def test_card_numbers_unique_across_many_users():
    for _ in range(200):
        UserFactory()
    assert len(set(LoyaltyCard.objects.values_list("number", flat=True))) == 200


def test_staff_user_has_no_card():
    staff = StaffFactory()
    assert staff.role == "staff"
    assert not LoyaltyCard.objects.filter(user=staff).exists()


def test_create_superuser_is_staff_role():
    admin = User.objects.create_superuser("root@example.com", "pass12345!word")
    assert admin.role == "staff"
    assert admin.is_staff and admin.is_superuser
    assert not LoyaltyCard.objects.filter(user=admin).exists()


def test_db_enforces_case_insensitive_email_uniqueness():
    User.objects.create_user("a@x.com", "pass12345!word")
    with pytest.raises(IntegrityError), transaction.atomic():
        User.objects.bulk_create([User(email="A@x.com", password="x")])
