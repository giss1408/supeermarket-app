import pytest
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

from payments import services
from payments.models import PaymentMethod, PaymentMethodChange
from tests.factories import PaymentMethodFactory, StaffFactory

pytestmark = pytest.mark.django_db


def test_create_writes_one_row():
    user = StaffFactory()
    m = services.create_method(
        user=user, provider="wave", phone_number="07 01 02 03 04", instructions="Pay"
    )
    assert m.phone_number == "+2250701020304"
    (c,) = PaymentMethodChange.objects.all()
    assert c.payment_method == m
    assert c.provider == "wave"
    assert c.changed_by == user
    assert c.changed_by_email == user.email
    assert c.old_phone_number is None and c.old_is_active is None
    assert c.new_phone_number == "+2250701020304" and c.new_is_active is True


def test_update_writes_old_and_new():
    m = PaymentMethodFactory(phone_number="+2250700000001", is_active=True)
    user = StaffFactory()
    services.update_method(m, user=user, phone_number="0505050505", is_active=False)
    m.refresh_from_db()
    assert m.phone_number == "+2250505050505" and m.is_active is False
    (c,) = PaymentMethodChange.objects.all()
    assert (c.old_phone_number, c.new_phone_number) == ("+2250700000001", "+2250505050505")
    assert (c.old_is_active, c.new_is_active) == (True, False)


def test_noop_update_writes_no_row():
    m = PaymentMethodFactory(display_name="Wave", instructions="Pay")
    services.update_method(
        m, user=None, phone_number="07 00 00 00 01", display_name="Wave", instructions="Pay"
    )
    assert PaymentMethodChange.objects.count() == 0


def test_display_name_only_edit_writes_row():
    m = PaymentMethodFactory(display_name="Old")
    services.update_method(m, user=None, display_name="New")
    (c,) = PaymentMethodChange.objects.all()
    assert (c.old_display_name, c.new_display_name) == ("Old", "New")
    assert c.old_phone_number == c.new_phone_number == "+2250700000001"


def test_instructions_only_edit_writes_row():
    m = PaymentMethodFactory(instructions="Send to me")
    services.update_method(m, user=None, instructions="Send to other")
    (c,) = PaymentMethodChange.objects.all()
    assert (c.old_instructions, c.new_instructions) == ("Send to me", "Send to other")


def test_create_and_delete_record_text_fields():
    m = services.create_method(
        user=None, provider="wave", phone_number="0700000001", display_name="W", instructions="I"
    )
    services.delete_method(m, user=None)
    created, deleted = PaymentMethodChange.objects.order_by("id")
    assert created.old_display_name is None and created.old_instructions is None
    assert (created.new_display_name, created.new_instructions) == ("W", "I")
    assert (deleted.old_display_name, deleted.old_instructions) == ("W", "I")
    assert deleted.new_display_name is None and deleted.new_instructions is None


def test_stale_instance_does_not_overwrite_newer_values():
    PaymentMethodFactory()
    a = PaymentMethod.objects.get()
    b = PaymentMethod.objects.get()
    services.update_method(b, user=None, phone_number="0505050505")
    services.update_method(a, user=None, instructions="Hello")
    stored = PaymentMethod.objects.get()
    assert stored.phone_number == "+2250505050505" and stored.instructions == "Hello"
    assert a.phone_number == "+2250505050505"  # caller's object refreshed
    last = PaymentMethodChange.objects.order_by("id").last()
    assert last.old_phone_number == last.new_phone_number == "+2250505050505"
    assert (last.old_instructions, last.new_instructions) == ("", "Hello")


def test_delete_writes_row_with_null_new_values():
    m = PaymentMethodFactory()
    user = StaffFactory()
    services.delete_method(m, user=user)
    assert not PaymentMethod.objects.exists()
    (c,) = PaymentMethodChange.objects.all()
    assert c.payment_method is None
    assert c.provider == "wave"
    assert c.old_phone_number == "+2250700000001" and c.old_is_active is True
    assert c.new_phone_number is None and c.new_is_active is None
    assert c.changed_by_email == user.email


def test_user_none_allowed():
    services.create_method(user=None, provider="wave", phone_number="0700000001")
    c = PaymentMethodChange.objects.get()
    assert c.changed_by is None and c.changed_by_email == ""


def test_email_snapshot_survives_user_deletion():
    user = StaffFactory()
    email = user.email
    services.create_method(user=user, provider="wave", phone_number="0700000001")
    get_user_model().objects.filter(pk=user.pk).delete()
    c = PaymentMethodChange.objects.get()
    assert c.changed_by is None
    assert c.changed_by_email == email


def test_invalid_number_writes_nothing():
    with pytest.raises(ValidationError):
        services.create_method(user=None, provider="wave", phone_number="07010203")
    assert PaymentMethod.objects.count() == 0 and PaymentMethodChange.objects.count() == 0
    m = PaymentMethodFactory()
    with pytest.raises(ValidationError):
        services.update_method(m, user=None, phone_number="+33612345678")
    m.refresh_from_db()
    assert m.phone_number == "+2250700000001"
    assert PaymentMethodChange.objects.count() == 0


def test_duplicate_provider_raises_validation_error():
    PaymentMethodFactory(provider="wave")
    with pytest.raises(ValidationError):
        services.create_method(user=None, provider="wave", phone_number="0700000009")
    assert PaymentMethodChange.objects.count() == 0


def test_failure_after_save_rolls_back(monkeypatch):
    def boom(*args, **kwargs):
        raise RuntimeError("boom")

    # create
    monkeypatch.setattr(PaymentMethodChange.objects, "create", boom)
    with pytest.raises(RuntimeError):
        services.create_method(user=None, provider="wave", phone_number="0700000001")
    assert PaymentMethod.objects.count() == 0
    # update
    m = PaymentMethodFactory()
    with pytest.raises(RuntimeError):
        services.update_method(m, user=None, phone_number="0500000002")
    m.refresh_from_db()
    assert m.phone_number == "+2250700000001"
    # delete
    with pytest.raises(RuntimeError):
        services.delete_method(m, user=None)
    assert PaymentMethod.objects.filter(pk=m.pk).exists()
    assert PaymentMethodChange.objects.count() == 0


def test_audit_rows_cannot_be_updated():
    services.create_method(user=None, provider="wave", phone_number="0700000001")
    c = PaymentMethodChange.objects.get()
    c.new_phone_number = "+2250000000000"
    with pytest.raises(RuntimeError):
        c.save()
    assert PaymentMethodChange.objects.get().new_phone_number == "+2250700000001"
