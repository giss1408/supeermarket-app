#!/usr/bin/env bash
# Regenerates app/packages/api_client from backend/openapi.yaml (dart-dio).
# Usage: app/tool/gen_api.sh   (works from any directory; needs Docker and Flutter on PATH)
set -euo pipefail

GENERATOR_VERSION="v7.10.0"   # the only place the generator version is pinned

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG="$ROOT/app/packages/api_client"
mkdir -p "$PKG"

# Keep the hand-maintained files (ignore list, pubspec.yaml); wipe everything else so
# removed schemas disappear.
find "$PKG" -mindepth 1 -maxdepth 1 \
  ! -name '.openapi-generator-ignore' ! -name 'pubspec.yaml' -exec rm -rf {} +

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$ROOT:/local" \
  "openapitools/openapi-generator-cli:$GENERATOR_VERSION" generate \
  -i /local/backend/openapi.yaml \
  -g dart-dio \
  --type-mappings decimal=String \
  -o /local/app/packages/api_client \
  --additional-properties=pubName=api_client,pubVersion=1.0.0,serializationLibrary=json_serializable

cd "$PKG"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .

# Machine-specific or tool-state files must never be committed.
rm -rf "$PKG/.dart_tool" "$PKG/pubspec.lock"
