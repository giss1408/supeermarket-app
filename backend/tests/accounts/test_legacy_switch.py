"""LEGACY_AUTH_ENABLED=0 removes the app's own e-mail register/login/refresh/logout: people sign in
at the auth service."""

import json

from tests.test_prod_settings import run_py

PROBE = """
    import json
    import django
    django.setup()
    from django.urls import Resolver404, resolve

    def exists(path):
        try:
            resolve(path)
            return True
        except Resolver404:
            return False

    paths = ("auth/register", "auth/login", "auth/refresh", "auth/logout", "me", "me/card")
    print(json.dumps({p: exists("/api/v1/" + p) for p in paths}))
"""


def probe(env: dict[str, str | None]) -> dict[str, bool]:
    result = run_py(PROBE, env)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout.strip().splitlines()[-1])


def test_the_apps_own_login_endpoints_are_gone_when_switched_off_but_the_api_stays():
    out = probe({"LEGACY_AUTH_ENABLED": "0"})
    assert [out[f"auth/{p}"] for p in ("register", "login", "refresh", "logout")] == [False] * 4
    assert out["me"] and out["me/card"]  # the profile endpoints stay: they only want a token


def test_they_exist_by_default():
    out = probe({})
    assert all(out[f"auth/{p}"] for p in ("register", "login", "refresh", "logout"))
