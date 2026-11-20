"""DELETE /me tells the auth service by the opaque auth user id (no phone number is kept anywhere here); a failure is queued and retried."""

import uuid
from datetime import timedelta

import pytest
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APIClient

from accounts import erasures
from accounts.models import AuthErasure, User
from tests.sso_helpers import bearer, token

pytestmark = pytest.mark.django_db


@pytest.fixture
def outcome(sso_on, monkeypatch):
    state = {"answer": True, "calls": []}

    def fake(auth_user_id):
        state["calls"].append(auth_user_id)
        return state["answer"]

    monkeypatch.setattr("accounts.sso.erase_identity", fake)
    return state


def delete_me(sub):
    return APIClient().delete("/api/v1/me", **bearer(token(sub)))


def test_deleting_the_account_erases_the_row_then_tells_auth_by_id(outcome):
    sub = uuid.uuid4()
    APIClient().get("/api/v1/me", **bearer(token(sub)))  # opened on first use
    assert delete_me(sub).status_code == 204
    assert not User.objects.filter(auth_user_id=sub).exists()
    assert outcome["calls"] == [sub] and AuthErasure.objects.count() == 0


def test_the_apps_own_accounts_have_nothing_to_tell_auth(outcome):
    from tests.factories import UserFactory

    user = UserFactory()
    c = APIClient()
    c.force_authenticate(user)
    assert c.delete("/api/v1/me").status_code == 204
    assert outcome["calls"] == []


def test_when_auth_is_down_the_deletion_stands_and_the_call_is_queued_with_the_id_only(outcome):
    outcome["answer"] = False
    sub = uuid.uuid4()
    APIClient().get("/api/v1/me", **bearer(token(sub)))
    assert delete_me(sub).status_code == 204
    row = AuthErasure.objects.get()
    assert row.auth_user_id == sub and row.status == "pending" and row.attempts == 1
    assert {f.name for f in AuthErasure._meta.get_fields()} == {"id", "auth_user_id", "created_at", "attempts", "next_attempt_at", "status", "finished_at"}


def test_the_retry_grows_then_finishes_and_a_finished_row_is_purged(outcome):
    outcome["answer"] = False
    erasures.tell_auth(uuid.uuid4())
    row = AuthErasure.objects.get()
    assert erasures.process(row.created_at) == {"done": 0, "retry": 0, "gave_up": 0, "purged": 0}  # not due yet
    later = row.next_attempt_at + timedelta(seconds=1)
    assert erasures.process(later)["retry"] == 1
    row.refresh_from_db()
    assert row.attempts == 2 and row.next_attempt_at - later == timedelta(minutes=2)
    outcome["answer"] = True
    assert erasures.process(row.next_attempt_at + timedelta(seconds=1))["done"] == 1
    row.refresh_from_db()
    assert row.status == "done"
    assert erasures.process(timezone.now() + timedelta(days=8))["purged"] == 1


def test_after_the_maximum_age_it_gives_up_and_says_so_without_naming_anyone(outcome, caplog):
    outcome["answer"] = False
    erasures.tell_auth(uuid.uuid4())
    row = AuthErasure.objects.get()
    caplog.set_level("ERROR")
    out = erasures.process(row.created_at + erasures.max_age() + timedelta(days=1))
    assert out["gave_up"] == 1 and "GIVEN UP" in caplog.text and str(row.auth_user_id) not in caplog.text


def test_the_command_prints_counts_only(outcome, capsys):
    call_command("process_auth_erasures")
    assert capsys.readouterr().out.strip() == '{"done": 0, "retry": 0, "gave_up": 0, "purged": 0}'


def test_a_failure_to_queue_never_breaks_the_deletion(outcome, monkeypatch):
    outcome["answer"] = False

    def boom(**kw):
        raise RuntimeError("db down")

    monkeypatch.setattr(AuthErasure.objects, "create", boom)
    erasures.tell_auth(uuid.uuid4())  # does not raise
