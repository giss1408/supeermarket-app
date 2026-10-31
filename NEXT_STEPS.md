# NEXT_STEPS

Full detail: `docs/roadmap-next-session.md`. Branch `feat/mobile-app` (HEAD `5a06361`, **not pushed**). Backend is done and on `main`.

## Where we stopped
- Mobile Tasks 1-14 are committed and reviewed.
- Task 15 (loyalty card and account) is **uncommitted and untested**, about 15 files in `app/`. Its agent was stopped mid-write, so check `app/test/features/card/` for a missing or half-written file.
- Task 16 and the final review have not started.

## Do next, in order
1. `cd app && flutter analyze && flutter test`. Fix failures, then commit as `feat(app): loyalty card and account`. If the tree is broken beyond repair, `git stash` it and redo Task 15 from the plan.
2. Task 16, reduced scope (no device runs):
   - write, but don't run, `app/integration_test/offline_list_sync_test.dart` (with a `NetworkGate` seam in `api_provider.dart`)
   - add a CI step that builds the Android debug APK
   - add the README release checklist and env docs
   - remove `ACCESS_FINE_LOCATION` in the manifest with `tools:node="remove"`
   - append the mobile follow-ups to `docs/follow-ups.md`
3. One final whole-branch opus review (`80d0f66..HEAD`), one fix wave, one scoped re-review.
4. Finish the branch. Ask the user whether to merge, open a PR or keep it, and whether to push. **Do not push without a go-ahead.**
5. Clean up: remove the phone-run worktree, delete `.superpowers/sdd/2026-10-29-mobile-apps/`, stop container `supermarket-app-web-1`.

## Guardrails
- Never touch container `flariane-postgres-1`. Leave `agriTechCMS` alone.
- Don't commit `.env*`, `*.egg-info` or `.superpowers/`.
- Pins: Flutter 3.24.2, Dart 3.5.2.
- Later: staff mode needs its own spec and plan.
