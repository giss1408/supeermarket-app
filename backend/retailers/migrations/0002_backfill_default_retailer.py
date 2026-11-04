"""Attach all pre-multi-tenant content and staff to one "Default retailer".

Runs only when such rows exist, so a fresh database gets no retailer.
"""

import datetime

from django.db import migrations
from django.utils import timezone

CONTENT = [
    ("catalog", "Category"),
    ("catalog", "Product"),
    ("stores", "Store"),
    ("offers", "Flyer"),
    ("payments", "PaymentMethod"),
]


def backfill(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    staff = User.objects.filter(role__in=["staff", "retailer_staff"], retailer__isnull=True)
    models = [apps.get_model(app_label, name) for app_label, name in CONTENT]
    if not staff.exists() and not any(m.objects.filter(retailer__isnull=True).exists() for m in models):
        return
    Retailer = apps.get_model("retailers", "Retailer")
    Subscription = apps.get_model("retailers", "Subscription")
    retailer, created = Retailer.objects.get_or_create(
        slug="default", defaults={"name": "Default retailer", "status": "active"}
    )
    if created:
        now = timezone.now()
        Subscription.objects.create(
            retailer=retailer, starts_at=now, ends_at=now + datetime.timedelta(days=365)
        )
    for model in models:
        model.objects.filter(retailer__isnull=True).update(retailer=retailer)
    staff.update(role="retailer_staff", retailer=retailer)


class Migration(migrations.Migration):
    dependencies = [
        ("retailers", "0001_initial"),
        ("accounts", "0003_retailer_and_roles"),
        ("catalog", "0002_category_retailer_product_retailer"),
        ("stores", "0002_store_retailer"),
        ("offers", "0003_flyer_retailer"),
        ("payments", "0003_paymentmethod_retailer"),
    ]

    operations = [migrations.RunPython(backfill, migrations.RunPython.noop)]
