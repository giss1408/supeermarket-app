"""The product's calls back to the auth service, with the real client bodies.

Other tests replace these functions wholesale. Here: what is sent, how answers and failures are
read, and that nothing secret is logged."""

import uuid

import httpx
import pytest

from accounts import sso

KEY = "svc-key"


class FakeAuth:
    """Stands in for httpx.request / httpx.post: records calls, answers with a prepared response."""

    def __init__(self, status=200, body=None, error=None, text=None):
        self.status, self.body, self.error, self.text, self.calls = status, body, error, text, []

    def __call__(self, *args, **kw):
        method, url = (args[0], args[1]) if len(args) == 2 else ("POST", args[0])
        self.calls.append({"method": method, "url": url, **kw})
        if self.error:
            raise self.error
        request = httpx.Request(method, url)
        if self.text is not None:
            return httpx.Response(self.status, text=self.text, request=request)
        return httpx.Response(
            self.status, json=self.body if self.body is not None else {}, request=request
        )


@pytest.fixture
def auth(sso_on, monkeypatch):
    def install(**kw):
        fake = FakeAuth(**kw)
        monkeypatch.setattr(httpx, "request", fake)
        monkeypatch.setattr(httpx, "post", fake)
        return fake

    return install


def test_calls_carry_the_service_key_in_a_header_to_the_auth_url(auth):
    fake = auth(body={"active": True})
    assert sso.session_alive("tok") is True
    call = fake.calls[0]
    assert call["url"] == "http://auth.test/v1/introspect" and call["headers"] == {
        "X-Service-Key": KEY
    }
    assert call["json"] == {"token": "tok"}


@pytest.mark.parametrize("fn,arg", [(sso.session_alive, "tok"), (sso.sid_alive, "sid-1")])
def test_live_session_checks_answer_active_inactive_or_none_when_auth_is_down(auth, fn, arg):
    auth(body={"active": True})
    assert fn(arg) is True
    auth(body={"active": False})
    assert fn(arg) is False
    auth(error=httpx.ConnectError("down"))
    assert fn(arg) is None
    auth(status=500)
    assert fn(arg) is None
    auth(text="not json")
    assert fn(arg) is None


def test_live_checks_say_none_when_calls_are_not_configured(auth, settings):
    fake = auth(body={"active": True})
    settings.SSO_SERVICE_KEY = ""
    assert sso.session_alive("tok") is None and sso.sid_alive("sid") is None
    assert sso.display_name(uuid.uuid4()) == "" and sso.erase_identity(uuid.uuid4()) is None
    assert fake.calls == []


def test_display_name_is_best_effort_and_capped(auth):
    uid = uuid.uuid4()
    fake = auth(body={"display_name": "A" * 400})
    assert sso.display_name(uid) == "A" * 150
    assert fake.calls[0]["method"] == "GET" and fake.calls[0]["url"].endswith(
        f"/v1/service/users/{uid}"
    )
    auth(body={"display_name": None})
    assert sso.display_name(uid) == ""
    auth(error=httpx.ConnectError("down"))
    assert sso.display_name(uid) == ""


def test_erase_identity_reports_true_false_and_never_logs_the_person(auth, caplog):
    uid = uuid.uuid4()
    caplog.set_level("INFO")
    fake = auth(body={"result": "erased"})
    assert sso.erase_identity(uid) is True and fake.calls[0]["json"] == {"user_id": str(uid)}
    auth(status=503)
    assert sso.erase_identity(uid) is False
    auth(error=httpx.ConnectError("down"))
    assert sso.erase_identity(uid) is False
    assert "FAILED" in caplog.text and str(uid) not in caplog.text and KEY not in caplog.text


def test_enrol_staff_returns_the_auth_id_or_a_clear_error_code(auth):
    fake = auth(status=201, body={"user_id": "abc-123"})
    assert sso.enrol_staff("0701020304", "Awa") == "abc-123"
    sent = fake.calls[0]["json"]
    assert sent == {
        "phone": "0701020304",
        "display_name": "Awa",
        "role": "retailer_staff",
        "allow_existing": False,
    }
    auth(status=409, body={"detail": "phone_taken"})
    with pytest.raises(sso.EnrolError) as e:
        sso.enrol_staff("0701020304", "Awa")
    assert e.value.code == "phone_taken"
    auth(status=500, text="<html>oops</html>")
    with pytest.raises(sso.EnrolError) as e:
        sso.enrol_staff("0701020304", "Awa")
    assert e.value.code == "enrol_failed"
    auth(error=httpx.ConnectError("down"))
    with pytest.raises(sso.EnrolError) as e:
        sso.enrol_staff("0701020304", "Awa")
    assert e.value.code == "auth_unavailable"


def test_enrol_staff_needs_the_service_key(auth, settings):
    settings.SSO_SERVICE_KEY = ""
    with pytest.raises(sso.EnrolError) as e:
        sso.enrol_staff("0701020304", "Awa")
    assert e.value.code == "sso_not_configured"


def test_remove_staff_is_true_only_when_auth_says_200(auth):
    uid = uuid.uuid4()
    fake = auth(status=200)
    assert sso.remove_staff(uid) is True and fake.calls[0]["method"] == "DELETE"
    auth(status=404)
    assert sso.remove_staff(uid) is False
    auth(error=httpx.ConnectError("down"))
    assert sso.remove_staff(uid) is False


def test_login_at_auth_returns_status_and_body_or_503(auth):
    fake = auth(body={"access_token": "t"})
    assert sso.login_at_auth("0700000000", "pw", "123456") == (200, {"access_token": "t"})
    assert fake.calls[0]["json"]["totp"] == "123456" and fake.calls[0]["json"]["app"] == "admin"
    sso.login_at_auth("0700000000", "pw", "")
    assert "totp" not in fake.calls[1]["json"]
    auth(status=401, body={"detail": "invalid_credentials"})
    assert sso.login_at_auth("0700000000", "pw", "") == (401, {"detail": "invalid_credentials"})
    auth(error=httpx.ConnectError("down"))
    assert sso.login_at_auth("0700000000", "pw", "") == (503, {"detail": "auth_unavailable"})
    auth(text="not json")
    assert sso.login_at_auth("0700000000", "pw", "") == (503, {"detail": "auth_unavailable"})


def test_verify_is_none_when_sso_is_off_or_the_token_is_bad(settings, sso_on):
    from tests.sso_helpers import token

    assert sso.verify(token(uuid.uuid4())) is not None
    assert sso.verify("not-a-token") is None
    settings.SSO_ENABLED = False
    assert sso.verify(token(uuid.uuid4())) is None
