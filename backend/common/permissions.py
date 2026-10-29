from typing import Any

from rest_framework.permissions import SAFE_METHODS, BasePermission
from rest_framework.request import Request


class IsStaff(BasePermission):
    """Authenticated user whose role is "staff"."""

    def has_permission(self, request: Request, view: Any) -> bool:
        user = request.user
        return bool(user and user.is_authenticated and getattr(user, "role", None) == "staff")


class IsOwner(BasePermission):
    """Object-level: the object's ``user_id`` equals the requesting user's id."""

    def has_object_permission(self, request: Request, view: Any, obj: Any) -> bool:
        user = request.user
        return bool(user and user.is_authenticated and obj.user_id == user.id)


class ReadOnly(BasePermission):
    """Allows only safe (read-only) HTTP methods."""

    def has_permission(self, request: Request, view: Any) -> bool:
        return request.method in SAFE_METHODS
