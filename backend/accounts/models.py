import secrets
from typing import Any

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models, transaction
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

    def create_superuser(self, email: str, password: str | None = None, **extra: Any) -> "User":
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("role", User.Role.STAFF)
        return self.create_user(email, password, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        STAFF = "staff", "Staff"

    email = models.EmailField(unique=True)
    name = models.CharField(max_length=150, blank=True)
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.CUSTOMER)
    is_active = models.BooleanField(default=True)  # type: ignore[misc]
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    class Meta:
        constraints = [models.UniqueConstraint(Lower("email"), name="user_email_ci_unique")]

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []  # type: ignore[misc]

    def __str__(self) -> str:
        return self.email


class LoyaltyCard(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="card")
    number = models.CharField(max_length=CARD_DIGITS, unique=True)

    def __str__(self) -> str:
        return self.number
