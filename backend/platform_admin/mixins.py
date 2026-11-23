import time

from django.contrib.auth import logout
from django.contrib.auth.mixins import AccessMixin
from django.urls import reverse_lazy

from accounts import sso
from accounts.models import User


class PlatformAdminRequiredMixin(AccessMixin):
    """Session-authenticated platform admins only.

    Anonymous users go to the login page; any other authenticated user gets a 403."""

    login_url = reverse_lazy("platform:login")

    CHECK_EVERY_SECONDS = 60

    def dispatch(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        user = request.user
        if not user.is_authenticated or user.role != User.Role.PLATFORM_ADMIN:
            return self.handle_no_permission()
        sid = request.session.get("sso_sid")
        if sid and time.time() - request.session.get("sso_checked", 0) > self.CHECK_EVERY_SECONDS:
            # An admin switched off or signed out at the auth service must not keep a
            # dashboard session: ask auth (fails closed).
            if sso.sid_alive(sid) is not True:
                logout(request)
                return self.handle_no_permission()
            request.session["sso_checked"] = int(time.time())
        return super().dispatch(request, *args, **kwargs)
