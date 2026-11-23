import secrets
import uuid
from typing import Any

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models, transaction
from django.db.models import Q
from django.db.models.functions import Lower

CARD_DIGITS = 13


def generate_card_number() -> str:
    """Return a unique 13-digit numeric card number (DB unique constraint is the backstop)."""
    with transaction.atomic():
        while True:
            number = str(secrets.randbelow(10**CARD_DIGITS)).zfill(CARD_DIGITS)
            if not LoyaltyCard.objects.filter(number=number).exists():
                return number


class UserManager(BaseUserManager["User"]):
    use_in_migrations = True

    def get_by_natural_key(self, username: str | None) -> "User":
        # Case-insensitive login; also matches rows stored before emails were lowercased.
        return self.get(email__iexact=username)

    def create_user(self, email: str, password: str | None = None, **extra: Any) -> "User":
        if not email:
            raise ValueError("Email is required")
        with transaction.atomic(using=self._db):
            user = self.model(email=self.normalize_email(email).lower(), **extra)
            user.set_password(password)
            user.save(using=self._db)
            if user.role == User.Role.CUSTOMER:
                LoyaltyCard.objects.using(self._db).create(user=user, number=generate_card_number())
        return user

    def create_sso_customer(self, auth_user_id: uuid.UUID, name: str = "") -> "User":
        """A customer opened from an auth token on first use: no e-mail, no password here, a loyalty
        card like everyone."""
        with transaction.atomic(using=self._db):
            user = self.model(auth_user_id=auth_user_id, name=name, role=User.Role.CUSTOMER)
            user.set_unusable_password()
            user.save(using=self._db)
            LoyaltyCard.objects.using(self._db).create(user=user, number=generate_card_number())
        return user

    def create_superuser(self, email: str, password: str | None = None, **extra: Any) -> "User":
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("role", User.Role.PLATFORM_ADMIN)
        return self.create_user(email, password, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        RETAILER_STAFF = "retailer_staff", "Retailer staff"
        PLATFORM_ADMIN = "platform_admin", "Platform admin"

    # NULL for people who sign in through the auth service with a phone number (customers,
    # staff): they have no e-mail here.
    email = models.EmailField(unique=True, null=True, blank=True)
    # The opaque global user id in the auth service; the link between a token and this profile.
    auth_user_id = models.UUIDField(unique=True, null=True, blank=True, editable=False)
    name = models.CharField(max_length=150, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CUSTOMER)
    retailer = models.ForeignKey(
        "retailers.Retailer",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="users",
    )
    is_active = models.BooleanField(default=True)  # type: ignore[misc]
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    class Meta:
        constraints = [
            models.UniqueConstraint(Lower("email"), name="user_email_ci_unique"),
            # Retailer staff belong to exactly one retailer; nobody else belongs to any.
            models.CheckConstraint(
                condition=Q(role="retailer_staff", retailer__isnull=False)
                | (~Q(role="retailer_staff") & Q(retailer__isnull=True)),
                name="user_retailer_matches_role",
            ),
        ]

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []  # type: ignore[misc]

    def __str__(self) -> str:
        return self.email or self.name or str(self.auth_user_id)


class LoyaltyCard(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="card")
    number = models.CharField(max_length=CARD_DIGITS, unique=True)

    def __str__(self) -> str:
        return self.number


class AuthErasure(models.Model):
    """A person this product erased whose identity in the auth service could not be erased yet (auth
    unreachable). Only the opaque auth user
    id is kept, no phone number and no name; it is the only way to find her there. Retried by
    `manage.py process_auth_erasures`."""

    auth_user_id = models.UUIDField()
    created_at = models.DateTimeField(auto_now_add=True)
    attempts = models.PositiveIntegerField(default=1)
    next_attempt_at = models.DateTimeField(db_index=True)
    status = models.CharField(max_length=10, default="pending")  # pending | done | gave_up
    finished_at = models.DateTimeField(null=True, blank=True)

    def __str__(self) -> str:
        # never the auth user id: it must not reach logs or admin lists
        return f"AuthErasure #{self.pk} ({self.status})"
