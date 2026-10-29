import pytest
from django.http import Http404
from django.urls import path
from rest_framework import exceptions, serializers
from rest_framework.authentication import BaseAuthentication
from rest_framework.response import Response
from rest_framework.test import APIClient
from rest_framework.views import APIView


class Payload(serializers.Serializer):
    name = serializers.CharField()
    qty = serializers.IntegerField()

    def validate(self, attrs):
        if attrs.get("qty") == 13:
            raise serializers.ValidationError("Unlucky.")
        return attrs


class ValidationView(APIView):
    authentication_classes: list = []
    permission_classes: list = []

    def post(self, request):
        Payload(data=request.data).is_valid(raise_exception=True)
        return Response()  # pragma: no cover


class _Auth(BaseAuthentication):
    def authenticate(self, request):
        return None

    def authenticate_header(self, request):
        return "Bearer"


class RaiseView(APIView):
    authentication_classes = [_Auth]
    permission_classes: list = []
    exc: Exception = Http404()

    def get(self, request):
        raise self.exc


def raiser(exc):
    return type("V", (RaiseView,), {"exc": exc}).as_view()


class Teapot(exceptions.APIException):
    status_code = 418
    default_detail = "Short and stout."
    default_code = "I'm A Teapot"


urlpatterns = [
    path("validate/", ValidationView.as_view()),
    path("http404/", raiser(Http404())),
    path("notfound/", raiser(exceptions.NotFound())),
    path("noauth/", raiser(exceptions.NotAuthenticated())),
    path("authfail/", raiser(exceptions.AuthenticationFailed())),
    path("denied/", raiser(exceptions.PermissionDenied())),
    path("throttled/", raiser(exceptions.Throttled())),
    path("teapot/", raiser(Teapot())),
    path("boom/", raiser(RuntimeError("boom"))),
]

pytestmark = [pytest.mark.urls(__name__)]


@pytest.fixture
def client():
    return APIClient()


def test_validation_error_field(client):
    r = client.post("/validate/", {"qty": "x"}, format="json")
    assert r.status_code == 400
    assert r.json()["code"] == "validation_error"
    assert r.json()["detail"] == "Invalid input."
    assert set(r.json()["fields"]) == {"name", "qty"}
    assert isinstance(r.json()["fields"]["name"], list)


def test_non_field_errors(client):
    r = client.post("/validate/", {"name": "a", "qty": 13}, format="json")
    assert r.json()["fields"] == {"non_field_errors": ["Unlucky."]}


@pytest.mark.parametrize(
    ("url", "status", "code"),
    [
        ("/http404/", 404, "not_found"),
        ("/notfound/", 404, "not_found"),
        ("/noauth/", 401, "not_authenticated"),
        ("/authfail/", 401, "not_authenticated"),
        ("/denied/", 403, "permission_denied"),
        ("/throttled/", 429, "throttled"),
        ("/teapot/", 418, "i_m_a_teapot"),
    ],
)
def test_code_mapping(client, url, status, code):
    r = client.get(url)
    assert r.status_code == status
    body = r.json()
    assert body["code"] == code
    assert isinstance(body["detail"], str) and body["detail"]
    assert body["fields"] == {}


def test_unhandled_exception_stays_unhandled():
    c = APIClient(raise_request_exception=True)
    with pytest.raises(RuntimeError):
        c.get("/boom/")
