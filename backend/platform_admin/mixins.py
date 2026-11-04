from django.contrib.auth.mixins import AccessMixin
from django.urls import reverse_lazy

from accounts.models import User


class PlatformAdminRequiredMixin(AccessMixin):
    """Session-authenticated platform admins only.

    Anonymous users go to the login page; any other authenticated user gets a 403."""

    login_url = reverse_lazy("platform:login")

    def dispatch(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        user = request.user
        if not user.is_authenticated or user.role != User.Role.PLATFORM_ADMIN:
            return self.handle_no_permission()
        return super().dispatch(request, *args, **kwargs)
