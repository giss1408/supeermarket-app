from collections.abc import Sequence
from typing import Any, ClassVar, cast

from django.http import Http404
from drf_spectacular.utils import extend_schema
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import BaseThrottle, ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .models import LoyaltyCard, User
from .serializers import CardSerializer, LogoutSerializer, MeSerializer, RegisterSerializer


class AuthThrottleMixin:
    throttle_classes: ClassVar[Sequence[type[BaseThrottle]]] = [ScopedRateThrottle]
    throttle_scope = "auth"


class RegisterView(AuthThrottleMixin, generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    authentication_classes: list[type] = []


class LoginView(AuthThrottleMixin, TokenObtainPairView):
    pass


class RefreshView(AuthThrottleMixin, TokenRefreshView):
    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        try:
            return super().post(request, *args, **kwargs)
        except User.DoesNotExist as exc:  # token of a deleted account
            raise InvalidToken("Token is invalid or expired") from exc


class LogoutView(AuthThrottleMixin, APIView):
    authentication_classes: list[type] = []
    permission_classes = [AllowAny]
    serializer_class = LogoutSerializer

    @extend_schema(request=LogoutSerializer, responses={204: None})
    def post(self, request: Request) -> Response:
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MeSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_object(self) -> User:
        return cast(User, self.request.user)


class CardView(generics.RetrieveAPIView):
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self) -> LoyaltyCard:
        try:
            return cast(User, self.request.user).card
        except LoyaltyCard.DoesNotExist as exc:
            raise Http404 from exc
