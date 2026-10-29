"""Idempotent demo data for local development: ``python manage.py seed_demo``."""

import datetime
import os
from decimal import Decimal
from typing import Any

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from catalog.models import Category, Product
from offers.models import Flyer, Offer
from offers.services import publish_flyer, unpublish_flyer
from stores.models import OpeningHours, Store

# Dev-only defaults (documented in README); override with the DEMO_*_PASSWORD env vars.
DEFAULT_STAFF_PASSWORD = "demo-staff-pass-123"
DEFAULT_CUSTOMER_PASSWORD = "demo-customer-pass-123"
STAFF_EMAIL = "staff@example.com"
CUSTOMER_EMAIL = "customer@example.com"
FLYER_TITLE = "Demo weekly flyer"
FLYER_DAYS = 7

# category name -> [(product name, unit)]
CATALOG: dict[str, list[tuple[str, str]]] = {
    "Fruit & Vegetables": [
        ("Bananas", "1 kg"),
        ("Red apples", "1 kg"),
        ("Tomatoes on the vine", "500 g"),
        ("Carrots", "1 kg"),
    ],
    "Dairy & Eggs": [
        ("Whole milk", "1 l"),
        ("Free-range eggs", "10 pcs"),
        ("Gouda slices", "200 g"),
        ("Natural yoghurt", "500 g"),
    ],
    "Bakery": [
        ("Wholegrain bread", "750 g"),
        ("Butter croissants", "4 pcs"),
        ("Bread rolls", "6 pcs"),
        ("Apple pie", "1 pc"),
    ],
    "Meat & Fish": [
        ("Chicken breast", "500 g"),
        ("Minced beef", "500 g"),
        ("Salmon fillet", "250 g"),
        ("Smoked ham", "150 g"),
    ],
    "Pantry": [
        ("Spaghetti", "500 g"),
        ("Basmati rice", "1 kg"),
        ("Olive oil", "750 ml"),
        ("Tomato sauce", "400 g"),
    ],
    "Drinks": [
        ("Sparkling water", "6 x 1.5 l"),
        ("Orange juice", "1 l"),
        ("Ground coffee", "500 g"),
        ("Green tea", "20 bags"),
    ],
}

# (product name, price, old_price, badge_text)
OFFERS: list[tuple[str, str, str | None, str]] = [
    ("Bananas", "1.29", "1.79", "-28%"),
    ("Red apples", "1.99", None, ""),
    ("Whole milk", "0.99", "1.19", "Weekly deal"),
    ("Free-range eggs", "2.49", None, ""),
    ("Wholegrain bread", "1.89", "2.39", "-20%"),
    ("Butter croissants", "1.49", None, "New"),
    ("Chicken breast", "4.99", "6.49", "Save 1.50"),
    ("Salmon fillet", "3.99", None, ""),
    ("Spaghetti", "0.89", "1.29", "-30%"),
    ("Olive oil", "5.49", "7.99", "Best price"),
    ("Sparkling water", "2.99", None, ""),
    ("Ground coffee", "3.99", "5.49", "-27%"),
]

# name, address, postcode, lat, lng, phone, closed weekdays (0 = Monday)
STORES: list[tuple[str, str, str, str, str, str, set[int]]] = [
    ("Demo Market Central", "1 Market Square", "10001", "50.100000", "8.100000", "555-0101", {6}),
    ("Demo Market North", "22 Northgate Road", "10002", "50.140000", "8.120000", "555-0102", {6}),
    ("Demo Market Riverside", "5 River Walk", "10003", "50.090000", "8.150000", "555-0103", {6}),
    ("Demo Market Old Town", "9 Cobble Lane", "10004", "50.110000", "8.070000", "555-0104", {6}),
    ("Demo Market Express", "3 Station Plaza", "10005", "50.105000", "8.130000", "555-0105", set()),
]
CITY = "Exampleville"


def ean13(index: int) -> str:
    """A valid EAN-13 (with check digit) for a fictional product number."""
    digits = f"4000000{index:05d}"
    total = sum(int(d) * (3 if i % 2 else 1) for i, d in enumerate(digits))
    return digits + str((10 - total % 10) % 10)


class Command(BaseCommand):
    help = (
        "Create (or refresh) demo data for development. Idempotent; refuses to run if DEBUG=False."
    )

    def handle(self, *args: Any, **options: Any) -> None:
        if not settings.DEBUG:
            raise CommandError("seed_demo only runs with DEBUG=True (development).")
        staff_pw = os.environ.get("DEMO_STAFF_PASSWORD", DEFAULT_STAFF_PASSWORD)
        customer_pw = os.environ.get("DEMO_CUSTOMER_PASSWORD", DEFAULT_CUSTOMER_PASSWORD)
        try:
            validate_password(staff_pw)
            validate_password(customer_pw)
        except ValidationError as exc:
            raise CommandError(f"Demo password rejected: {' '.join(exc.messages)}") from None

        with transaction.atomic():
            products = self._catalog()
            self._flyer(products)
            self._stores()
            self._users(staff_pw, customer_pw)

        self.stdout.write(self.style.SUCCESS("Demo data ready."))
        self.stdout.write(f"  staff:    {STAFF_EMAIL}")
        self.stdout.write(f"  customer: {CUSTOMER_EMAIL}")
        self.stdout.write("  Passwords: DEMO_*_PASSWORD env vars, else the dev defaults in README.")

    def _catalog(self) -> dict[str, Product]:
        products: dict[str, Product] = {}
        index = 0
        for sort_order, (cat_name, items) in enumerate(CATALOG.items()):
            slug = cat_name.lower().replace(" & ", "-").replace(" ", "-")
            category, _ = Category.objects.update_or_create(
                slug=slug, defaults={"name": cat_name, "sort_order": sort_order}
            )
            for name, unit in items:
                index += 1
                product, _ = Product.objects.get_or_create(
                    name=name,
                    category=category,
                    defaults={"unit": unit, "ean": ean13(index)},
                )
                products[name] = product
        return products

    def _flyer(self, products: dict[str, Product]) -> None:
        today = timezone.localdate()
        start, end = today, today + datetime.timedelta(days=FLYER_DAYS - 1)
        flyer = Flyer.objects.filter(title=FLYER_TITLE).first()
        if flyer is None:
            flyer = Flyer.objects.create(title=FLYER_TITLE, valid_from=start, valid_to=end)
        for order, (name, price, old_price, badge) in enumerate(OFFERS):
            Offer.objects.update_or_create(
                flyer=flyer,
                product=products[name],
                defaults={
                    "price": Decimal(price),
                    "old_price": Decimal(old_price) if old_price else None,
                    "badge_text": badge,
                    "sort_order": order,
                },
            )
        if flyer.status == Flyer.Status.PUBLISHED and flyer.valid_from <= today <= flyer.valid_to:
            return  # already live today: keep it as is
        if flyer.status == Flyer.Status.PUBLISHED:
            unpublish_flyer(flyer)  # dates of a published flyer are frozen; move it via draft
        flyer.valid_from, flyer.valid_to = start, end
        flyer.save(update_fields=["valid_from", "valid_to", "updated_at"])
        try:
            publish_flyer(flyer)
        except ValidationError as exc:
            self.stderr.write(f"Demo flyer left as a draft: {' '.join(exc.messages)}")

    def _stores(self) -> None:
        for name, address, postcode, lat, lng, phone, closed in STORES:
            store, _ = Store.objects.update_or_create(
                name=name,
                defaults={
                    "address": address,
                    "city": CITY,
                    "postcode": postcode,
                    "latitude": Decimal(lat),
                    "longitude": Decimal(lng),
                    "phone": phone,
                    "is_active": True,
                },
            )
            for weekday in range(7):
                if weekday in closed:
                    OpeningHours.objects.filter(store=store, weekday=weekday).delete()
                    continue
                # Saturday is shorter than the weekdays.
                opens, closes = (
                    (datetime.time(8), datetime.time(18))
                    if weekday == 5
                    else (datetime.time(7), datetime.time(21))
                )
                OpeningHours.objects.update_or_create(
                    store=store, weekday=weekday, defaults={"opens": opens, "closes": closes}
                )

    def _users(self, staff_pw: str, customer_pw: str) -> None:
        User = get_user_model()
        for email, name, role, password in (
            (STAFF_EMAIL, "Demo Staff", "staff", staff_pw),
            (CUSTOMER_EMAIL, "Demo Customer", "customer", customer_pw),
        ):
            user = User.objects.filter(email__iexact=email).first()
            if user is None:
                User.objects.create_user(email, password, name=name, role=role)
            else:
                user.set_password(password)
                user.save(update_fields=["password"])
