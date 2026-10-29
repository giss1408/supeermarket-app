#!/usr/bin/env bash
# Fails when app/packages/api_client does not match a fresh generation from backend/openapi.yaml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

"$ROOT/app/tool/gen_api.sh"

if ! git diff --exit-code -- app/packages/api_client \
  || [ -n "$(git status --porcelain -- app/packages/api_client)" ]; then
  echo >&2
  echo "API client drift: app/packages/api_client is out of date with backend/openapi.yaml." >&2
  echo "Regenerate it with: app/tool/gen_api.sh   and commit the result." >&2
  exit 1
fi
echo "API client is up to date."
