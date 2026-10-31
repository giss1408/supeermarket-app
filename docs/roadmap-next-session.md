# Roadmap for the next session (mobile app, branch `feat/mobile-app`)

Written 2026-10-31 when credit ran out. Backend is done, merged to `main` and pushed. The mobile work lives on the local branch `feat/mobile-app` (HEAD `5a06361`, **not pushed**).

## State
- Tasks 1-14 of `docs/superpowers/plans/2026-10-29-mobile-apps.md` are committed and reviewed.
- **Task 15 (loyalty card `/card`, real Account tab, edit name, sign-out with unsynced-data dialog, delete account, card refresh) is UNCOMMITTED.** The implementer was stopped mid-work. The working tree holds about 15 changed files:
  - modified: `app/lib/app.dart`, `core/auth/session_controller.dart`, `core/router/{app_router,routes,sign_in_gate}.dart`, `features/account/ui/account_screen.dart`, `l10n/app_fr.arb`
  - new: `core/device/`, `features/card/`, `features/account/ui/{delete_account_dialog,edit_name_sheet,progress_dialog,unsynced_warning_dialog}.dart`, `test/features/card/`, `test/support/account_harness.dart`
- Task 16 and the final review have not started.

## Steps, in order
1. **Finish Task 15.** Run `cd app && flutter analyze && flutter test`. Fix what fails, read the diff, then commit as `feat(app): loyalty card and account`. If the tree looks broken beyond repair, `git stash` it and redo the task from the plan.
2. **Task 16 (reduced scope, ruling R29: no device or simulator runs):**
   - Write, but do not run, `app/integration_test/offline_list_sync_test.dart`, with a `NetworkGate` seam in `api_provider.dart`.
   - Add a CI step that builds the Android debug APK.
   - Add a README release checklist and env docs (`app/env/{dev,dev_ios,staging,prod}.json`).
   - In the Android manifest, add `xmlns:tools` and `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove"/>`.
   - Append the items below to `docs/follow-ups.md`.
3. **One final whole-branch review** (opus) of `feat/mobile-app`, from the plan commit `80d0f66` to HEAD. Triage the deferred minors listed below. One fix wave, then a scoped re-review.
4. **Finish the branch** (`superpowers:finishing-a-development-branch`). Ask the user whether to merge, open a PR, or keep the branch, and whether to push `feat/mobile-app`. Do not push without a go-ahead.
5. **Clean up:**
   - `git worktree remove` the phone-run worktree (in the session scratchpad, detached at `5a06361`).
   - Delete `.superpowers/sdd/2026-10-29-mobile-apps/` (git-ignored) after the review.
   - Stop the dev backend container `supermarket-app-web-1`.
   - Never touch container `flariane-postgres-1`.

## Follow-ups to record in `docs/follow-ups.md` (mobile)
- Server idempotency key for list creation. Today the first-sync adoption of ambiguous list creates is unbounded, and item adoption matches by content.
- Sync deletion tombstones.
- Provider app shortcuts (Wave, Orange Money, MTN MoMo deep links).
- Confirm the barcode symbology with the POS team.
- Per-store payment numbers (v1 has one set for the whole retailer).
- Staff mode: separate spec and plan (same Flutter app, role-gated).
- Image cache policy (R25).
- Minors deferred during task reviews:
  - `PaymentRepository` refresh controller shows one frame of stale state.
  - The "Vérifié…" line stays hidden after a failed refresh.
  - Categories are only upserted, never removed.
  - `ACCESS_FINE_LOCATION` arrives through the merged manifest of `geolocator_android`.
  - The minor lists from Tasks 4, 7, 9, 10, 11 and 12 are in the ledger.
- Native behavior is untested on devices, and the e2e test is untested. Only a manual Android run via USB happened, and it passed.

## Process notes
- Ledger with rulings R1-R29: `.superpowers/sdd/2026-10-29-mobile-apps/progress.md`. Briefs and reports are in the same folder.
- User directives: fewer reviews, no more local device runs, e2e test written at the end only.
- Pins: Flutter 3.24.2 and Dart 3.5.2. Do not commit `.env*`, `*.egg-info` or `.superpowers/`. Leave `agriTechCMS` alone.
- Remote: `https://github.com/giss1408/supeermarket-app.git`. The spelling is as the user gave it.
