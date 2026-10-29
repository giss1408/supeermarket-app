"""Container health check: GET /healthz on the local gunicorn.

Django rejects requests whose Host header is not in ALLOWED_HOSTS, and the container is probed
as 127.0.0.1, so we send the first ALLOWED_HOSTS entry as the Host header. /healthz is exempt
from the HTTPS redirect, so plain HTTP inside the container is fine.
"""

import os
import sys
import urllib.request


def first_host(allowed_hosts: str) -> str:
    """First ALLOWED_HOSTS entry as a usable Host header (leading '.' wildcard stripped)."""
    entry = allowed_hosts.split(",")[0].strip().lstrip(".")
    return entry or "localhost"


def main() -> int:
    host = first_host(os.environ.get("ALLOWED_HOSTS", "localhost"))
    request = urllib.request.Request("http://127.0.0.1:8000/healthz", headers={"Host": host})
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            return 0 if response.status == 200 else 1
    except Exception:
        return 1


if __name__ == "__main__":
    sys.exit(main())
