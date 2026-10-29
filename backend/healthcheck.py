"""Container health check: GET /healthz on the local gunicorn.

Django rejects requests whose Host header is not in ALLOWED_HOSTS, and the container is probed
as 127.0.0.1, so we send the first ALLOWED_HOSTS entry as the Host header. /healthz is exempt
from the HTTPS redirect, so plain HTTP inside the container is fine.
"""

import os
import sys
import urllib.request

host = os.environ.get("ALLOWED_HOSTS", "localhost").split(",")[0].strip() or "localhost"
request = urllib.request.Request("http://127.0.0.1:8000/healthz", headers={"Host": host})
try:
    with urllib.request.urlopen(request, timeout=3) as response:
        sys.exit(0 if response.status == 200 else 1)
except Exception:
    sys.exit(1)
