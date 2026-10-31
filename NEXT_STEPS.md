# NEXT_STEPS

Mobile app (Tasks 1-16) is done, reviewed once and merged to `main`. Backend is on `main` too.

## Status
- `flutter analyze` clean, 378 tests pass, Android debug APK builds (CI builds it too).
- `app/integration_test/offline_list_sync_test.dart` is written but **never run**: needs a dev backend and a device.
- Final whole-branch review done; two findings were deferred (see `docs/follow-ups.md`, "Mobile app").

## Do next
1. Run the integration test and the README release checklist (`app/README.md`) on a real device.
2. Fix the two deferred review findings (sign-out race on list mutations; `_failRestore` on transient errors).
3. Set the real `staging.json` / `prod.json` hosts, signing config, store listings.
4. Staff mode needs its own spec and plan.

## Guardrails
- Never touch container `flariane-postgres-1` (or the other flariane containers). Leave `agriTechCMS` alone.
- Don't commit `.env*`, `*.egg-info` or `.superpowers/`.
- Pins: Flutter 3.24.2, Dart 3.5.2.
