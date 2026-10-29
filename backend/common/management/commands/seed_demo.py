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
from payments.models import PaymentMethod
from payments.services import create_method, update_method
from stores.models import OpeningHours, Store

# Dev-only defaults (documented in README); override with the DEMO_*_PASSWORD env vars.
DEFAULT_STAFF_PASSWORD = "demo-staff-pass-123"
DEFAULT_CUSTOMER_PASSWORD = "demo-customer-pass-123"
STAFF_EMAIL = "staff@example.com"
CUSTOMER_EMAIL = "customer@example.com"
FLYER_TITLE = "Prospectus de la semaine"
FLYER_DAYS = 7

# slug, category name, [(product name, unit)]
CATALOG: list[tuple[str, str, list[tuple[str, str]]]] = [
    (
        "fruits-legumes",
        "Fruits et légumes",
        [
            ("Bananes plantain", "1 kg"),
            ("Mangues", "1 kg"),
            ("Tomates", "500 g"),
            ("Aubergines", "1 kg"),
        ],
    ),
    (
        "produits-laitiers-oeufs",
        "Produits laitiers et œufs",
        [
            ("Lait entier", "1 L"),
            ("Œufs frais", "30 unités"),
            ("Fromage portion", "8 portions"),
            ("Yaourt nature", "500 g"),
        ],
    ),
    (
        "boulangerie",
        "Boulangerie",
        [
            ("Pain de mie", "500 g"),
            ("Croissants", "4 unités"),
            ("Baguette", "1 unité"),
            ("Gâteau au coco", "1 unité"),
        ],
    ),
    (
        "viandes-poissons",
        "Viandes et poissons",
        [
            ("Poulet entier", "1 kg"),
            ("Bœuf haché", "500 g"),
            ("Poisson capitaine", "1 kg"),
            ("Sardines en boîte", "125 g"),
        ],
    ),
    (
        "epicerie",
        "Épicerie",
        [
            ("Riz parfumé", "5 kg"),
            ("Huile de palme", "1 L"),
            ("Attiéké", "1 kg"),
            ("Concentré de tomate", "400 g"),
        ],
    ),
    (
        "boissons",
        "Boissons",
        [
            ("Eau minérale", "paquet de 6 x 1,5 L"),
            ("Jus d'orange", "1 L"),
            ("Café moulu", "250 g"),
            ("Thé vert", "20 sachets"),
        ],
    ),
]

# (product name, price XOF, old_price XOF, badge_text)
OFFERS: list[tuple[str, str, str | None, str]] = [
    ("Bananes plantain", "750", "1000", "-25%"),
    ("Mangues", "1000", None, ""),
    ("Lait entier", "1100", "1300", "Offre de la semaine"),
    ("Œufs frais", "2500", None, ""),
    ("Pain de mie", "800", "1000", "-20%"),
    ("Croissants", "1000", None, "Nouveau"),
    ("Poulet entier", "3500", "4500", "Économisez 1000 F"),
    ("Poisson capitaine", "4500", None, ""),
    ("Riz parfumé", "5500", "7500", "-27%"),
    ("Huile de palme", "1800", "2300", "Meilleur prix"),
    ("Eau minérale", "1500", None, ""),
    ("Café moulu", "2000", "2500", "-20%"),
]

# name, address, city, lat, lng, phone, closed weekdays (0 = Monday)
STORES: list[tuple[str, str, str, str, str, str, set[int]]] = [
    (
        "Supermarché Cocody Angré",
        "Boulevard des Martyrs, Angré 8e tranche",
        "Abidjan",
        "5.401500",
        "-3.987000",
        "+2252722000101",
        set(),
    ),
    (
        "Supermarché Marcory Zone 4",
        "Rue du Canal, Zone 4",
        "Abidjan",
        "5.298000",
        "-3.998000",
        "+2252721000102",
        {6},
    ),
    (
        "Supermarché Yopougon Siporex",
        "Avenue principale de Siporex",
        "Abidjan",
        "5.336000",
        "-4.085000",
        "+2252723000103",
        {6},
    ),
    (
        "Supermarché Plateau",
        "Avenue Franchet d'Esperey",
        "Abidjan",
        "5.322000",
        "-4.021000",
        "+2252720000104",
        {6},
    ),
    (
        "Supermarché Bouaké Centre",
        "Avenue Houphouët-Boigny",
        "Bouaké",
        "7.690000",
        "-5.030000",
        "+2252731000105",
        {6},
    ),
]
POSTCODE = "01"

# provider -> (display name, obviously fake number, short instructions)
PAYMENT_METHODS: dict[str, tuple[str, str, str]] = {
    "wave": (
        "Wave",
        "+2250100000001",
        "Envoyez le montant au numéro Wave ci-dessus, puis présentez la confirmation en caisse.",
    ),
    "orange_money": (
        "Orange Money",
        "+2250700000002",
        "Envoyez le montant au numéro Orange Money ci-dessus, puis présentez le SMS reçu.",
    ),
    "mtn_momo": (
        "MTN MoMo",
        "+2250500000003",
        "Envoyez le montant au numéro MTN MoMo ci-dessus, puis présentez le SMS reçu.",
    ),
}


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
            self._payment_methods()
            self._users(staff_pw, customer_pw)

        self.stdout.write(self.style.SUCCESS("Demo data ready."))
        self.stdout.write(f"  staff:    {STAFF_EMAIL}")
        self.stdout.write(f"  customer: {CUSTOMER_EMAIL}")
        self.stdout.write("  Passwords: DEMO_*_PASSWORD env vars, else the dev defaults in README.")

    def _catalog(self) -> dict[str, Product]:
        products: dict[str, Product] = {}
        index = 0
        for sort_order, (slug, cat_name, items) in enumerate(CATALOG):
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
        for name, address, city, lat, lng, phone, closed in STORES:
            store, _ = Store.objects.update_or_create(
                name=name,
                defaults={
                    "address": address,
                    "city": city,
                    "postcode": POSTCODE,
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

    def _payment_methods(self) -> None:
        for provider, (display_name, phone, instructions) in PAYMENT_METHODS.items():
            fields = {
                "phone_number": phone,
                "display_name": display_name,
                "instructions": instructions,
                "is_active": True,
            }
            method = PaymentMethod.objects.filter(provider=provider).first()
            if method is None:
                create_method(user=None, provider=provider, **fields)
            else:
                update_method(method, user=None, **fields)  # audits only real changes

    def _users(self, staff_pw: str, customer_pw: str) -> None:
        User = get_user_model()
        for email, name, role, password in (
            (STAFF_EMAIL, "Équipe démo", "staff", staff_pw),
            (CUSTOMER_EMAIL, "Client démo", "customer", customer_pw),
        ):
            user = User.objects.filter(email__iexact=email).first()
            if user is None:
                User.objects.create_user(email, password, name=name, role=role)
            else:
                user.set_password(password)
                user.save(update_fields=["password"])
