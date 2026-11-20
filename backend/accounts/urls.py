from django.conf import settings
from django.urls import path

from .views import CardView, LoginView, LogoutView, MeView, RefreshView, RegisterView

# The app's own e-mail register/login/refresh/logout. With LEGACY_AUTH_ENABLED=0 they do not exist: people sign up and sign in at the platform
# `auth` service (phone + password, WhatsApp activation), like in flariane and fidelia, and this API only verifies the tokens.
legacy_auth = [
    path("auth/register", RegisterView.as_view()),
    path("auth/login", LoginView.as_view()),
    path("auth/refresh", RefreshView.as_view()),
    path("auth/logout", LogoutView.as_view()),
]

urlpatterns = [
    *(legacy_auth if settings.LEGACY_AUTH_ENABLED else []),
    path("me", MeView.as_view()),
    path("me/card", CardView.as_view()),
]
