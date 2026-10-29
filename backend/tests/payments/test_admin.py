import pytest
from django.urls import reverse

from payments.models import PaymentMethod, PaymentMethodChange
from tests.factories import PaymentMethodFactory, StaffFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def admin_user(client):
    user = StaffFactory(is_staff=True, is_superuser=True)
    client.force_login(user)
    return user


def test_add_via_admin_normalises_and_audits(client, admin_user):
    resp = client.post(
        reverse("admin:payments_paymentmethod_add"),
        {
            "provider": "wave",
            "phone_number": "07 01 02 03 04",
            "display_name": "Wave",
            "instructions": "",
            "is_active": "on",
        },
    )
    assert resp.status_code == 302
    m = PaymentMethod.objects.get()
    assert m.phone_number == "+2250701020304"
    c = PaymentMethodChange.objects.get()
    assert c.changed_by == admin_user and c.new_phone_number == "+2250701020304"
    assert c.old_phone_number is None


def test_invalid_number_shows_form_error(client, admin_user):
    resp = client.post(
        reverse("admin:payments_paymentmethod_add"),
        {"provider": "wave", "phone_number": "07010203", "is_active": "on"},
    )
    assert resp.status_code == 200
    assert "phone_number" in resp.context["adminform"].form.errors
    assert not PaymentMethod.objects.exists()
    assert not PaymentMethodChange.objects.exists()


def test_change_via_admin_audits_and_provider_readonly(client, admin_user):
    m = PaymentMethodFactory(provider="wave")
    url = reverse("admin:payments_paymentmethod_change", args=[m.pk])
    page = client.get(url)
    assert "provider" not in page.context["adminform"].form.fields
    resp = client.post(
        url,
        {
            "provider": "mtn_momo",  # must be ignored
            "phone_number": "05 05 05 05 05",
            "display_name": "",
            "instructions": "",
        },
    )
    assert resp.status_code == 302
    m.refresh_from_db()
    assert m.provider == "wave"
    assert m.phone_number == "+2250505050505" and m.is_active is False
    c = PaymentMethodChange.objects.get()
    assert c.old_phone_number == "+2250700000001" and c.new_phone_number == "+2250505050505"
    assert c.old_is_active is True and c.new_is_active is False
    assert c.changed_by == admin_user


def test_delete_via_admin_audits(client, admin_user):
    m = PaymentMethodFactory()
    resp = client.post(reverse("admin:payments_paymentmethod_delete", args=[m.pk]), {"post": "yes"})
    assert resp.status_code == 302
    assert not PaymentMethod.objects.exists()
    c = PaymentMethodChange.objects.get()
    assert c.new_phone_number is None and c.changed_by == admin_user and c.provider == "wave"


def test_bulk_delete_audits_each(client, admin_user):
    PaymentMethodFactory.create_all()
    resp = client.post(
        reverse("admin:payments_paymentmethod_changelist"),
        {
            "action": "delete_selected",
            "_selected_action": list(PaymentMethod.objects.values_list("pk", flat=True)),
            "post": "yes",
        },
    )
    assert resp.status_code == 302
    assert not PaymentMethod.objects.exists()
    changes = PaymentMethodChange.objects.all()
    assert changes.count() == 3
    assert {c.provider for c in changes} == {"wave", "orange_money", "mtn_momo"}
    assert all(c.changed_by == admin_user and c.new_phone_number is None for c in changes)


def test_change_admin_is_read_only(client, admin_user):
    m = PaymentMethodFactory()
    PaymentMethodChange.objects.create(payment_method=m, provider="wave")
    c = PaymentMethodChange.objects.get()
    assert client.get(reverse("admin:payments_paymentmethodchange_add")).status_code == 403
    assert client.get(reverse("admin:payments_paymentmethodchange_changelist")).status_code == 200
    # view-only page renders but cannot be posted/deleted
    change_url = reverse("admin:payments_paymentmethodchange_change", args=[c.pk])
    assert client.post(change_url, {"provider": "x"}).status_code == 403
    delete_url = reverse("admin:payments_paymentmethodchange_delete", args=[c.pk])
    assert client.post(delete_url, {"post": "yes"}).status_code == 403
    assert PaymentMethodChange.objects.filter(pk=c.pk).exists()


@pytest.mark.parametrize(
    "raw",
    ["+225 07 01 02 03 04", "00225 0701020304", "07 01 02 03 04", "+2250701020304"],
)
def test_admin_accepts_phone_variants(client, admin_user, raw):
    resp = client.post(
        reverse("admin:payments_paymentmethod_add"),
        {"provider": "wave", "phone_number": raw, "is_active": "on"},
    )
    assert resp.status_code == 302
    assert PaymentMethod.objects.get().phone_number == "+2250701020304"


@pytest.mark.parametrize("raw", ["x" * 41, "07010203", "0701O20304"])
def test_admin_rejects_bad_phone_with_field_error(client, admin_user, raw):
    resp = client.post(
        reverse("admin:payments_paymentmethod_add"),
        {"provider": "wave", "phone_number": raw, "is_active": "on"},
    )
    assert resp.status_code == 200
    assert "phone_number" in resp.context["adminform"].form.errors
    assert not PaymentMethod.objects.exists()


def test_admin_widget_has_no_maxlength_14(client, admin_user):
    html = client.get(reverse("admin:payments_paymentmethod_add")).content.decode()
    assert 'maxlength="14"' not in html


def test_change_admin_shows_text_columns(client, admin_user):
    from payments import services

    m = PaymentMethodFactory()
    services.update_method(m, user=admin_user, instructions="Other number")
    c = PaymentMethodChange.objects.get()
    page = client.get(reverse("admin:payments_paymentmethodchange_change", args=[c.pk]))
    assert "Other number" in page.content.decode()
    ma = __import__("django.contrib.admin", fromlist=["site"]).site._registry[PaymentMethodChange]
    assert "new_instructions" in ma.list_display
