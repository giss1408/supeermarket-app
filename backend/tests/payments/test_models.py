import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from payments.models import PaymentMethod, PaymentMethodChange
from tests.factories import PaymentMethodFactory, RetailerFactory

pytestmark = pytest.mark.django_db


def test_duplicate_provider_integrity_error():
    PaymentMethodFactory(provider="wave")
    with pytest.raises(IntegrityError), transaction.atomic():
        PaymentMethodFactory(provider="wave")


def test_instructions_over_500_fails_full_clean():
    m = PaymentMethodFactory.build(instructions="x" * 501)
    with pytest.raises(ValidationError) as exc:
        m.full_clean()
    assert "instructions" in exc.value.message_dict


def test_phone_validator_on_model():
    m = PaymentMethodFactory.build(phone_number="0701020304")
    with pytest.raises(ValidationError) as exc:
        m.full_clean()
    assert "phone_number" in exc.value.message_dict


def test_all_three_providers_and_ordering():
    PaymentMethodFactory.create_all()
    assert list(PaymentMethod.objects.values_list("provider", flat=True)) == [
        "mtn_momo",
        "orange_money",
        "wave",
    ]


def test_str():
    m = PaymentMethodFactory(provider="orange_money")
    assert str(m) == "Orange Money (+2250700000001)"
    c = PaymentMethodChange(provider="wave", old_phone_number="a", new_phone_number="b")
    assert "wave" in str(c)


def test_two_retailers_can_share_payment_provider():
    PaymentMethodFactory(provider="wave", retailer=RetailerFactory())
    PaymentMethodFactory(provider="wave", retailer=RetailerFactory())


def test_same_retailer_payment_provider_rejected():
    retailer = RetailerFactory()
    PaymentMethodFactory(provider="wave", retailer=retailer)
    with pytest.raises(IntegrityError), transaction.atomic():
        PaymentMethodFactory(provider="wave", retailer=retailer)
