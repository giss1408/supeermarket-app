# Mobile Apps Implementation Plan (Customer App + Payment Backend Additions)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mobile-money payment numbers to the backend (Tasks 1-3), then build the Flutter customer app for Android and iOS (Tasks 4-16): offers and flyer, offline-capable shopping lists, stores, loyalty card, account and a Pay screen.

**Architecture:** Backend gets a small `payments` Django app plus French/XOF settings. The app is layered screens → Riverpod controllers → repositories → (Drift database + generated Dart API client); the local database is the source of truth, shopping-list edits go through an outbox that a sync service pushes and pulls with `updated_since`.

**Tech Stack:** Backend: Django 5.2, DRF, PostgreSQL (existing). App: Flutter (stable, version pinned in README/CI), Dart, flutter_riverpod, go_router, drift, dio, flutter_secure_storage, connectivity_plus, geolocator, url_launcher, barcode_widget, screen_brightness, wakelock_plus, intl, uuid; openapi-generator (`dart-dio`) run through Docker.

**Spec:** `docs/superpowers/specs/2026-10-29-mobile-apps-design.md` (backend spec: `docs/superpowers/specs/2026-10-29-backend-design.md`)

**Execution notes:** Work on branch `feat/mobile-app`. Backend tests run from `backend/` against this project's compose `db` (host port 5434, container `supermarket-app-db-1`) with a Python 3.13 venv (`pip install -e ".[dev]"`; the repo's `backend/.venv` is broken, create a new one outside the repo). NEVER touch the unrelated container `flariane-postgres-1`. Existing backend tests that assert English text must be updated in Task 3, keeping `code` assertions. Flutter is installed (`/Users/regis/installations/flutter`); iOS simulators and the Android SDK exist; default Java is JDK 24 (use 17/21 for Gradle).

## Global Constraints

- Market: Côte d'Ivoire, French only (`fr`), currency XOF. API prices are decimal strings like `"1500.00"`; the app never parses money as floating point and displays `"1 500 F CFA"` (no decimals).
- Phone numbers: `+225` followed by 10 digits, one `PaymentMethod` per provider (`wave`, `orange_money`, `mtn_momo`).
- Payment staff endpoints require `current_password` on create and update; there is no DELETE; throttle scope `staff_sensitive` default `5/min`; every change is audit-logged.
- Payment methods are refreshed from the server EVERY time the Pay screen opens (when online); offline or failed refresh shows exactly: `Ces numéros sont peut-être périmés. Confirmez le numéro à la caisse avant de payer.`
- Android `minSdk` 24, iOS deployment target 14; placeholder application id `com.example.supermarket`.
- API base URL only through `--dart-define-from-file=env/<name>.json` key `API_BASE_URL` (dev: `http://10.0.2.2:8000` on Android emulator, `http://localhost:8000` on iOS simulator); cleartext HTTP in debug builds only.
- The Dart client is generated from `backend/openapi.yaml`, committed, and CI fails on drift; never hand-edit generated code.
- The server's `detail` text is never shown to users; messages come from French ARB strings keyed by the error `code`. Field errors (`fields`) are shown under their form fields.
- On sign-out or account switch, wipe user-scoped data (lists, items, outbox, loyalty card); public caches and payment methods stay.
- Follow cursor pages to the end with a cap of 50 pages. Sync uses only server timestamps; the device clock never decides what is "current".
- Original white-label design: provider names are plain text, no third-party logos; 48 dp touch targets, AA contrast, layouts work at 200% text scale.

## Review Focus

- Two requests getting 401 at the same time must trigger exactly one token refresh and both retry once (Task 9).
- A wrong device clock (year 2000 or 2040) must not change which flyer is current or break list sync (Tasks 10, 13).
- Signing in as a different user must show nothing of the previous user: lists, card and unsynced outbox operations are gone (Tasks 9, 15).
- The app being killed mid-sync must not duplicate lists or items, and must not lose queued operations (Task 13).
- Admin phone input variants (`07 01 02 03 04`, `+225 07 01 02 03 04`, `00225 0701020304`, old 8-digit numbers, letters) normalise to `+2250701020304` or are rejected with a field error, never a 500 (Tasks 1, 2).

## File Structure

```
backend/payments/{apps,models,validators,services,serializers,views,urls,admin}.py  + migrations/
backend/tests/payments/
app/pubspec.yaml  analysis_options.yaml  l10n.yaml  env/{dev,staging,prod}.json
app/tool/{gen_api.sh,check_api_drift.sh}      app/packages/api_client/ (generated, committed)
app/lib/main.dart  app/lib/app.dart
app/lib/core/{api,auth,db,sync,theme,l10n,money,errors,ui,router,config}/
app/lib/features/{offers,lists,stores,card,account,payment}/
app/test/  app/integration_test/
```

---

### Task 1: Payment models, phone validation, audit trail, admin

**Files:**
- Create: `backend/payments/{__init__,apps,models,validators,services,admin}.py`, `backend/payments/migrations/0001_initial.py`, `backend/tests/payments/{__init__,test_validators,test_models,test_services,test_admin}.py`
- Modify: `backend/config/settings/base.py` (INSTALLED_APPS), `backend/tests/factories.py` (add `PaymentMethodFactory`)

**Interfaces:**
- Produces: `normalize_ci_phone(raw: str) -> str` (raises `django.core.exceptions.ValidationError`); `PaymentMethod(provider, phone_number, display_name, instructions, is_active, updated_at)` with `Provider` choices `wave|orange_money|mtn_momo`, unique `provider`; `PaymentMethodChange(payment_method FK null on delete SET_NULL, provider, changed_by FK null SET_NULL, changed_by_email, changed_at, old_phone_number, new_phone_number, old_is_active, new_is_active)`; services `create_method(*, user, **fields) -> PaymentMethod`, `update_method(method, *, user, **fields) -> PaymentMethod`, `delete_method(method, *, user) -> None`, each writing exactly one change row inside `transaction.atomic()`.

- [ ] **Step 1: Write failing tests.** `test_validators.py`: `normalize_ci_phone` returns `"+2250701020304"` for `"+2250701020304"`, `"+225 07 01 02 03 04"`, `"00225 0701020304"`, `"07-01-02-03-04"`, `"07.01.02.03.04"`, `"0701020304"`; raises for `"0701020"` (7 digits), `"07010203"` (old 8-digit format), `"+22507010203"`, `"+2250701020304 5"`, `"+33612345678"`, `"0701O20304"` (letter O), `""`. `test_models.py`: duplicate provider -> `IntegrityError`; `instructions` over 500 characters fails `full_clean`. `test_services.py`: create writes one change row (old values null, `changed_by_email` snapshot); update writes old/new numbers and `is_active`; delete writes a row with new values null and the method gone; the change row survives deleting the user (email snapshot kept, `changed_by` null); an exception inside the service rolls back both rows. `test_admin.py`: creating, editing and deleting a method in Django admin (logged in as `StaffFactory` superuser) writes change rows via the services; the change admin is read-only (no add/change/delete permission).
- [ ] **Step 2: Run** `cd backend && pytest tests/payments -v`. Expected: FAIL (no module).
- [ ] **Step 3: Implement** the app, validator (strip spaces/dots/dashes, map `00225`/`+225`/leading `0` forms, require exactly 10 digits after `+225`), models, services, and admin (`ModelAdmin.save_model`/`delete_model` call the services; `PaymentMethodChange` admin read-only). Generate the migration. Add the app to `INSTALLED_APPS`.
- [ ] **Step 4: Run** `pytest tests/payments -v` then the full suite once. Expected: PASS; `ruff check`, `ruff format --check`, `mypy`, `python manage.py makemigrations --check` clean.
- [ ] **Step 5: Commit** `feat(payments): payment methods, phone validation, audit trail`.

---

### Task 2: Payment API (public + staff) with password step-up and throttle

**Files:**
- Create: `backend/payments/{serializers,views,urls}.py`, `backend/tests/payments/{test_public_api,test_staff_api}.py`
- Modify: `backend/config/urls.py` (include `payments.urls` under `api/v1/`), `backend/staff/urls.py` (register `payment-methods`), `backend/config/settings/base.py` (`DEFAULT_THROTTLE_RATES["staff_sensitive"]` from env `STAFF_SENSITIVE_THROTTLE_RATE`, default `"5/min"`), `backend/tests/staff/test_permissions.py` (add the new routes), `backend/tests/test_contract_runtime.py` (add the new endpoints), `backend/openapi.yaml` (regenerate), `.env.prod.example`, `README.md`

**Interfaces:**
- Consumes: Task 1 models and services; `IsStaff`; `DefaultCursorPagination` (page size 100 subclass).
- Produces: `GET /api/v1/payment-methods` (public, `authentication_classes = []`, only `is_active`, fields `provider, phone_number, display_name, instructions, updated_at`, ordered by provider, cursor paginated); `GET/POST /api/v1/staff/payment-methods`, `GET/PATCH /api/v1/staff/payment-methods/{id}` (no PUT, no DELETE); write serializer accepts `provider` (create only), `phone_number`, `display_name`, `instructions`, `is_active` and write-only `current_password`.

- [ ] **Step 1: Write failing tests.** Public: `test_public_lists_only_active_methods`, `test_public_includes_updated_at`, `test_public_ignores_bad_bearer_token`, `test_public_empty_page`. Staff: `test_anonymous_401_customer_403_on_every_route`, `test_create_requires_current_password` (missing -> 400 `fields.current_password`, wrong -> 400 same field, nothing written, no audit row), `test_create_with_password_writes_audit_row`, `test_patch_number_requires_password_and_normalises` (input `"07 01 02 03 04"` stored `"+2250701020304"`), `test_patch_invalid_number_400_field_error` (old 8-digit, letters, other country), `test_duplicate_provider_400`, `test_provider_not_changeable_on_patch`, `test_deactivate_via_patch_hides_from_public`, `test_put_and_delete_405`, `test_current_password_never_in_response`, `test_step_up_throttled_after_five_attempts_per_user` (6th write attempt within a minute -> 429 standard shape; a different staff user is unaffected; clear the cache between tests), `test_failed_attempts_count_toward_throttle`. Extend the parametrized permission test and the contract-vs-runtime test (success responses of both endpoints validate against the generated schema).
- [ ] **Step 2: Run** `pytest tests/payments tests/staff/test_permissions.py -v`. Expected: FAIL.
- [ ] **Step 3: Implement** serializers (password check via `request.user.check_password`), viewsets (`get_throttles` applies `ScopedRateThrottle` scope `staff_sensitive` to `create`/`partial_update`), public list view, URL wiring; writes call the Task 1 services with `user=request.user`. Add `extend_schema` annotations so `spectacular --validate --fail-on-warn` is clean; regenerate `backend/openapi.yaml`.
- [ ] **Step 4: Run** the full suite with `pytest --cov` (coverage gates for accounts/offers/shopping still >= 85%), ruff, mypy, `makemigrations --check`, `python manage.py check --deploy --fail-level WARNING` with the CI dummy env, and the OpenAPI drift test. Expected: all PASS.
- [ ] **Step 5: Commit** `feat(payments): public and staff payment-method API with password step-up`.

---

### Task 3: French language, XOF currency, Ivorian demo seed

**Files:**
- Modify: `backend/config/settings/base.py` (`LANGUAGE_CODE = "fr"`, `LANGUAGES`, `LocaleMiddleware` after `SessionMiddleware`, `CURRENCY` default `"XOF"`), `backend/common/management/commands/seed_demo.py`, `backend/tests/**` (English-text assertions), `README.md`, `.env.example`, `.env.prod.example`
- Test: `backend/tests/test_language.py`, `backend/tests/test_seed_demo.py`

**Interfaces:**
- Consumes: Task 1-2 models; existing `seed_demo` helpers.
- Produces: error `code` values stay English snake_case; validation messages (`fields.*`, Django validators) come back in French; `seed_demo` creates Ivorian demo data and three obviously fake payment methods (`+2250700000001` wave, `+2250500000002` orange_money, `+2250100000003` mtn_momo).

- [ ] **Step 1: Write failing tests.** `test_language.py`: registering with a too-short password returns a French message under `fields.password` with and without `Accept-Language: fr`; `Accept-Language: en` still returns English (client choice honoured); `code` is `validation_error` either way; unknown URL JSON 404 keeps the English `code`. `test_seed_demo.py`: seeded flyer prices are whole XOF amounts, three payment methods exist and are returned by `GET /api/v1/payment-methods`, stores are in Côte d'Ivoire (lat 4-11, lng -9 to -2), the command stays idempotent and still refuses when `DEBUG` is False.
- [ ] **Step 2: Run** the new tests. Expected: FAIL.
- [ ] **Step 3: Implement** the settings and seed changes; fix existing tests that assert English `detail`/field text (assert on `code`, or on `Accept-Language: en` requests); regenerate `backend/openapi.yaml` only if the schema changed; README: language and currency notes.
- [ ] **Step 4: Run** the full suite with `pytest --cov`, ruff, mypy, `makemigrations --check`, `check --deploy`, the drift tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: French locale, XOF currency, Ivorian demo seed`.

---

### Task 4: Flutter scaffold, configuration, CI

**Files:**
- Create: `app/` (via `flutter create --org com.example --project-name supermarket_app --platforms android,ios .`), `app/env/{dev,staging,prod}.json`, `app/l10n.yaml`, `app/lib/l10n/app_fr.arb`, `app/lib/core/config/app_config.dart`, `app/lib/main.dart`, `app/lib/app.dart`, `app/test/smoke_test.dart`
- Modify: `app/pubspec.yaml` (exact pinned dependency versions), `app/analysis_options.yaml`, `app/android/**` (minSdk 24, debug-only cleartext in `src/debug/AndroidManifest.xml`, Gradle on JDK 17/21 without committing a machine-specific path), `app/ios/**` (deployment target 14.0, `NSAllowsLocalNetworking`), `.github/workflows/ci.yml` (job `app`), `README.md` (app section), `.gitignore`

**Interfaces:**
- Produces: `AppConfig` with `static const apiBaseUrl = String.fromEnvironment('API_BASE_URL')`, `currencyCode = 'XOF'`, `locale = Locale('fr')`; `AppLocalizations` generated for `fr`; a `ProviderScope` + `MaterialApp.router` placeholder shell.

- [ ] **Step 1: Write the failing test** `smoke_test.dart`: pumping `SupermarketApp` shows the French app name from `app_fr.arb` and uses locale `fr`; `AppConfig.currencyCode == 'XOF'`.
- [ ] **Step 2: Run** `cd app && flutter test`. Expected: FAIL.
- [ ] **Step 3: Scaffold and configure** as listed. Pin the Flutter version used here in README and CI (`subosito/flutter-action` with that exact version). CI job `app`: `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Generated-code convention: `*.g.dart` and `*.freezed.dart` produced by build_runner for the app are NOT committed (git-ignored; CI and developers run build_runner); the ONLY committed generated code is `app/packages/api_client/` (Task 5).
- [ ] **Step 4: Verify** `flutter analyze` and `flutter test` pass; `flutter build apk --debug --dart-define-from-file=env/dev.json` succeeds (report how the JDK 24 issue was handled); `flutter build ios --simulator --no-codesign` succeeds if Xcode allows it, else report why not.
- [ ] **Step 5: Commit** `feat(app): flutter scaffold, configuration and CI`.

---

### Task 5: Generated API client and fixtures

**Files:**
- Create: `app/tool/gen_api.sh`, `app/tool/check_api_drift.sh`, `app/packages/api_client/**` (generated), `app/test/fixtures/*.json`, `app/test/api_client/parse_fixtures_test.dart`, `app/lib/core/api/{api_provider,paging}.dart`, `app/test/core/paging_test.dart`
- Modify: `app/pubspec.yaml` (path dependency `api_client`), `.github/workflows/ci.yml` (drift step), `README.md`

**Interfaces:**
- Produces: package `api_client` generated by `openapitools/openapi-generator-cli` (version pinned) with generator `dart-dio` from `backend/openapi.yaml`; `Dio dioProvider` configured with `AppConfig.apiBaseUrl`, JSON, French `Accept-Language`, 15 s connect and 30 s receive timeouts; `Future<List<T>> fetchAllPages<T>(Future<({List<T> items, String? next})> Function(String? cursor) fetch, {int maxPages = 50})`.

- [ ] **Step 1: Capture fixtures.** Start the backend (`docker compose up -d db`, run migrations and `seed_demo`), then save real responses as JSON fixtures: `/flyers/current`, `/flyers`, `/offers`, `/categories`, `/stores` (with and without `lat`/`lng`), `/stores/{id}`, `/payment-methods`, `/lists/{id}` (a list with a product item and a free-text item), `/me`, `/me/card`, `/auth/login`, and one error body (`{code, detail, fields}`).
- [ ] **Step 2: Write failing tests.** `parse_fixtures_test.dart`: every fixture parses with the generated models; money fields are `String` (`"1500.00"`); `distance_km` is nullable; list-item `product` is a summary object or null; the error body parses; request models for `POST /lists/{id}/items` serialise `product` as an integer. `paging_test.dart`: follows `next` to the end, stops with a `StateError` after `maxPages`, returns items in order, handles an empty first page.
- [ ] **Step 3: Run** `flutter test`. Expected: FAIL.
- [ ] **Step 4: Implement** `gen_api.sh` (Docker generator, then `dart run build_runner build` in the package) and `check_api_drift.sh` (regenerates and `git diff --exit-code app/packages/api_client`); commit the generated package; add the CI step. If the generator cannot represent something in the OpenAPI file (nullable, `allOf`, read-only), STOP and report the exact schema snippet instead of editing generated code.
- [ ] **Step 5: Verify** `flutter analyze` clean for the package and app, tests PASS, drift script exits 0. **Commit** `feat(app): generated API client, fixtures and paging helper`.

---

### Task 6: Core UI kit: theme, money, errors

**Files:**
- Create: `app/lib/core/theme/{brand,app_theme}.dart`, `app/lib/core/money/xof.dart`, `app/lib/core/errors/{app_error,error_mapper}.dart`, `app/lib/core/ui/{price_text,empty_state,error_view,offline_banner,skeleton}.dart`, tests under `app/test/core/`; bundle an open-licensed font in `app/assets/fonts/` and declare it in `pubspec.yaml`
- Modify: `app/lib/l10n/app_fr.arb`

**Interfaces:**
- Produces: `String formatXof(String decimal)` (`"1500.00"` -> `"1 500 F CFA"`, groups separated by U+202F, a U+00A0 before `F CFA`, no decimals, round half away from zero, throws `FormatException` for non-decimal input, never goes through `double`); `String formatCiPhone(String e164)` (`"+2250701020304"` -> `"07 01 02 03 04"`) and `String ciPhoneForCopy(String e164)` (`"0701020304"`); `class Brand {String name; Color seed; String? logoAsset; Map<PaymentProvider, String?> providerLogos;}`; `ThemeData lightTheme(Brand)`, `darkTheme(Brand)`; `sealed class AppError` with `NetworkError`, `TimeoutError`, `ApiError({String code, int status, Map<String, List<String>> fields})`, `UnknownError`; `AppError mapDioException(DioException e)`; `String AppError.userMessage(AppLocalizations l)`.

- [ ] **Step 1: Write failing tests.** Money: `"0.00"` -> `0 F CFA`; `"500.00"`; `"1500.00"` -> `1 500 F CFA`; `"1234567.00"` -> `1 234 567 F CFA`; `"1500.50"` -> `1 501 F CFA`; `"abc"` and `""` throw. Phone: format and copy values as above; `formatCiPhone` throws for a non-`+225` value. Errors: `{code: "throttled"}` -> French throttle message; `validation_error` keeps `fields`; unknown code -> generic French message; the server `detail` text never appears in `userMessage`; a `DioException` with no response -> `NetworkError`; timeout -> `TimeoutError`; non-JSON body -> `UnknownError`. Widgets: `PriceText` shows the formatted price and a struck-through old price; `EmptyState`/`ErrorView` (retry callback fires)/`OfflineBanner` render French text; with text scale 2.0 and a 320 dp wide viewport none of them overflows; a golden test for `PriceText` light and dark.
- [ ] **Step 2: Run** `flutter test test/core`. Expected: FAIL.
- [ ] **Step 3: Implement** the files and French ARB strings (error messages per `code`: `validation_error`, `not_authenticated`, `permission_denied`, `not_found`, `throttled`, `conflict`, `server_error`, `csrf_failed`, `bad_request`, `unsupported_media_type`, fallback). Default `Brand` is neutral with a green seed.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): theme, money formatting, error mapping, shared widgets`.

---

### Task 7: Local database (Drift)

**Files:**
- Create: `app/lib/core/db/{app_database,tables}.dart`, `app/lib/core/db/daos/{public_dao,lists_dao,outbox_dao,card_dao,payment_dao,sync_meta_dao}.dart`, `app/test/core/db/*_test.dart`, `app/lib/core/db/drift_schemas/` (schema dump v1)
- Modify: `app/pubspec.yaml`

**Interfaces:**
- Produces: `AppDatabase(QueryExecutor e)` with `schemaVersion = 1` and tables `categories, products, flyers, offers, stores, opening_hours, payment_methods, shopping_lists (localId uuid PK, remoteId nullable unique, name, serverUpdatedAt nullable, dirty, deletedLocally), list_items (localId, listLocalId FK cascade, remoteId nullable, productId/productName/productUnit/productImageUrl nullable, text, quantity, checked, dirty, createdAt), loyalty_card (number, barcodeValue), outbox_ops (id autoincrement, opType, listLocalId, itemLocalId nullable, payloadJson, state pending|inFlight|failed, attempts, lastError, createdAt), sync_meta (key, value)`; `Future<void> PublicDao.replaceCurrentFlyer(FlyerRow flyer, List<OfferRow> offers)` (one transaction); `Future<void> AppDatabase.wipeUserData()` (lists, items, outbox, loyalty card, and `sync_meta` keys `lists_last_pull`, `last_user_id`); `Future<int> OutboxDao.pendingCount()`.

- [ ] **Step 1: Write failing tests** (in-memory executor): `replaceCurrentFlyer` replaces offers atomically and a failure part-way leaves the old flyer intact; `wipeUserData` removes lists, items, outbox, card and the listed `sync_meta` keys but keeps flyers, offers, stores, payment methods and `payment_last_checked`; deleting a list cascades its items; `remoteId` uniqueness enforced; `OutboxDao.pendingCount` counts pending and inFlight; a migration test scaffold from the schema dump.
- [ ] **Step 2: Run** `flutter test test/core/db`. Expected: FAIL.
- [ ] **Step 3: Implement** tables, DAOs and `build_runner` generation (generated `*.g.dart` files are git-ignored, per the Task 4 convention; commit only the Drift schema dump).
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): local database schema and DAOs`.

---

### Task 8: Routing shell and navigation

**Files:**
- Create: `app/lib/core/router/{app_router,sign_in_gate}.dart`, `app/lib/core/ui/app_scaffold.dart`, placeholder screens `app/lib/features/{offers,lists,stores,account}/<name>_screen.dart`, `app/test/core/router_test.dart`
- Modify: `app/lib/app.dart`, `app/lib/l10n/app_fr.arb`

**Interfaces:**
- Produces: `GoRouter` with `StatefulShellRoute.indexedStack` (branches `/offers`, `/lists`, `/stores`, `/account`), routes `/offers/flyers`, `/lists/:id`, `/stores/:id`, `/pay`, and modal `/sign-in?from=` and `/register?from=`; `Future<bool> requireSignIn(BuildContext context, WidgetRef ref)` (returns true immediately when signed in, otherwise pushes `/sign-in` and returns true only after authentication, returning the user to the originating screen); `final sessionProvider` stub (replaced by Task 9) exposing `Guest` or `SignedIn`.

- [ ] **Step 1: Write failing tests.** Four French-labelled bottom tabs; each tab keeps its own stack and scroll offset after switching tabs; `/pay` is reachable as a guest; as a guest `requireSignIn` opens sign-in and, after a fake successful sign-in, returns true and lands back on the originating route; closing sign-in returns false; unknown route shows a French not-found page.
- [ ] **Step 2: Run** `flutter test test/core/router_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement** the router and placeholders.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): navigation shell with four tabs and sign-in gate`.

---

### Task 9: Authentication and session

**Files:**
- Create: `app/lib/core/auth/{token_store,session,session_controller,auth_interceptor,auth_repository}.dart`, `app/lib/features/account/{sign_in_screen,register_screen}.dart`, tests under `app/test/core/auth/` and `app/test/features/account/`
- Modify: `app/lib/core/api/api_provider.dart`, `app/lib/core/router/sign_in_gate.dart`

**Interfaces:**
- Consumes: Task 5 client, Task 6 errors, Task 7 `wipeUserData`/`pendingCount`.
- Produces: `abstract class TokenStore {Future<String?> readRefresh(); Future<void> writeRefresh(String t); Future<void> clear();}` (secure-storage implementation and an in-memory fake); `sealed class Session` with `Guest` and `SignedIn(User user)`; `SessionController extends Notifier<Session>` with `Future<void> restore()`, `Future<void> signIn(String email, String password)`, `Future<void> register({email, password, name})` (registers, then signs in, because registration returns no tokens), `Future<int> unsyncedCount()`, `Future<void> signOut({required bool discardUnsynced})`; `AuthInterceptor` attaching the in-memory access token and, on a 401 from a non-auth endpoint, running ONE shared refresh (`_refreshOnce()` returning a shared `Future`), storing the rotated refresh token, and retrying the request at most once.

- [ ] **Step 1: Write failing tests** (fake `HttpClientAdapter`, fake `TokenStore`, in-memory DB). Interceptor: `test_two_concurrent_401s_trigger_one_refresh_and_both_retry` (Review Focus); `test_request_is_retried_at_most_once`; `test_refresh_failure_signs_out_to_guest_and_wipes_user_data_keeping_public_cache`; `test_rotated_refresh_token_is_stored`; `test_auth_endpoints_are_not_refreshed_on_401`. Session: `test_restore_with_valid_refresh_token_signs_in`; `test_restore_without_token_is_guest`; `test_sign_in_trims_email_and_stores_refresh_not_access`; `test_register_then_signs_in_and_shows_field_errors_on_400`; `test_sign_out_calls_logout_best_effort_even_offline_then_wipes`; `test_sign_out_with_pending_outbox_reports_count_and_discard_flag_controls_wipe`; `test_signing_in_as_a_different_user_wipes_previous_users_data_first` using `sync_meta.last_user_id` (Review Focus); `test_same_user_sign_in_keeps_data`. Widgets: sign-in and register screens show field errors from `ApiError.fields`, a loading state, French strings, and return to `from` after success.
- [ ] **Step 2: Run** `flutter test test/core/auth test/features/account`. Expected: FAIL.
- [ ] **Step 3: Implement.** Access token only in memory; refresh token only in secure storage; replace the Task 8 `sessionProvider` stub.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): authentication, session and token refresh`.

---

### Task 10: Public data repositories and Offers tab

**Files:**
- Create: `app/lib/features/offers/{data/offers_repository,state/offers_controller,ui/offers_home_screen,ui/offer_card,ui/offer_detail_sheet,ui/flyer_archive_screen}.dart`, `app/lib/core/sync/public_refresher.dart`, tests under `app/test/features/offers/`
- Modify: `app/lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: Tasks 5, 6, 7, 8.
- Produces: `OffersRepository` with `Future<void> refreshCurrentFlyer({bool force = false})` (TTL 15 min, uses `GET /flyers/current` and `fetchAllPages` for categories), `Stream<FlyerWithOffers?> watchCurrent()`, `Stream<List<OfferRow>> watchOffers({String? categorySlug, String query = ''})`, `Future<void> refreshArchive()`; `OfferDetailSheet({required OfferRow offer, VoidCallback? onAddToList})` (the button is hidden when `onAddToList` is null; Task 14 supplies it).

- [ ] **Step 1: Write failing tests** (fake API, in-memory DB). Repository: cached flyer is emitted before the network returns (stale-while-revalidate); a refresh replaces offers atomically; a refresh inside the TTL does not hit the network unless `force`; **the current flyer is the one the server returned, never derived from the device date** (device clock set to year 2000 still shows it) (Review Focus); on network failure the cached flyer stays and a banner flag is set; if the device date is past the cached flyer's `valid_to` show the note `Ce prospectus est peut-être terminé`; category and text filters run on local data; a 404 from `/flyers/current` produces the empty state, not an error. Widgets: skeleton -> offers grid; header shows dates formatted in French (`du 28 oct. au 3 nov.`); price/old price/badge; filter chips; empty and error states; detail sheet shows the add-to-list button only when the callback is set; golden for `OfferCard` light and dark at text scale 1.0 and 2.0.
- [ ] **Step 2: Run** `flutter test test/features/offers`. Expected: FAIL.
- [ ] **Step 3: Implement** the repository, controllers and screens.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): offers tab with cached flyer and filters`.

---

### Task 11: Stores tab

**Files:**
- Create: `app/lib/features/stores/{data/stores_repository,state/stores_controller,ui/stores_screen,ui/store_detail_screen}.dart`, `app/lib/core/location/location_service.dart`, `app/lib/core/util/{haversine,open_now,maps_link}.dart`, tests under `app/test/features/stores/` and `app/test/core/util/`

**Interfaces:**
- Produces: `double distanceKm(double lat1, double lng1, double lat2, double lng2)`; `bool isOpenNow(List<HoursRow> week, DateTime now)`; `Uri mapsUri(double lat, double lng)` (`https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`); `abstract class LocationService {Future<LocationResult> current();}` (`Granted(lat, lng)`, `Denied`, `Disabled`) with a geolocator implementation; `StoresRepository.refresh({bool force})` (TTL 1 day) and `watchStores({String query})`.

- [ ] **Step 1: Write failing tests.** `distanceKm` for a known pair (Abidjan 5.3600,-4.0083 to Yamoussoukro 6.8276,-5.2893) within 1 km of 200 km; identical points 0; `isOpenNow` for a closed day, before opening, exactly at opening (open), exactly at closing (closed), and a store with no rows; stores sort by distance when granted and alphabetically with a search field when denied or disabled; the distance label shows `1,2 km` style French formatting; the detail screen highlights today's hours, `tel:` link built from the phone number, the Maps URI, and a link to `/pay`; offline shows cached stores with the banner.
- [ ] **Step 2: Run** `flutter test test/features/stores test/core/util`. Expected: FAIL.
- [ ] **Step 3: Implement.** Android/iOS permission strings in French (`Info.plist` `NSLocationWhenInUseUsageDescription`, Android manifest permission).
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): stores tab with distance sorting and details`.

---

### Task 12: Payment feature (Pay screen)

**Files:**
- Create: `app/lib/features/payment/{data/payment_repository,state/payment_controller,ui/pay_screen,ui/provider_card}.dart`, tests under `app/test/features/payment/`
- Modify: store detail (entry), account screen placeholder (entry), `app/lib/l10n/app_fr.arb`

**Interfaces:**
- Produces: `PaymentRepository.refresh() -> Future<RefreshResult>` (`Refreshed(at)` or `Failed(error)`; stores `payment_last_checked` in `sync_meta` only on success), `Stream<List<PaymentMethodRow>> watchMethods()`, `Stream<DateTime?> watchLastChecked()`; `PayScreen` calls `refresh()` on EVERY open and on pull-to-refresh; clipboard copy uses `ciPhoneForCopy`.

- [ ] **Step 1: Write failing tests.** Opening the Pay screen twice calls `refresh()` twice (fake repository counts); a successful refresh replaces the cached methods and shows `Vérifié aujourd'hui 14:32` from the stored time; a failed or offline refresh shows the exact warning text from Global Constraints and still shows cached methods; empty list shows the empty state telling the customer to ask at the till; each card shows the plain-text provider name, `formatCiPhone` number in large type, instructions, and `Mis à jour le <date>`; the copy button copies `0701020304`-style digits and shows a confirmation; a refresh that removes a provider removes it from the screen; guest users can open the screen; text scale 2.0 does not overflow.
- [ ] **Step 2: Run** `flutter test test/features/payment`. Expected: FAIL.
- [ ] **Step 3: Implement** the feature and the two entry points.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): pay by mobile money screen`.

---

### Task 13: Shopping-list sync engine (outbox)

**Files:**
- Create: `app/lib/core/sync/{lists_api,outbox_repository,outbox_pusher,lists_puller,lists_reconciler,sync_coordinator}.dart`, `app/lib/features/lists/data/lists_repository.dart`, tests under `app/test/core/sync/`

**Interfaces:**
- Consumes: Task 5 client, Task 7 DAOs, Task 9 session.
- Produces: `abstract class ListsApi {Future<RemoteList> createList(String name); Future<void> renameList(int id, String name); Future<void> deleteList(int id); Future<RemoteItem> createItem(int listId, ItemPayload p); Future<void> updateItem(int listId, int itemId, ItemPayload p); Future<void> deleteItem(int listId, int itemId); Future<Page<RemoteList>> listLists({DateTime? updatedSince, String? cursor}); Future<RemoteListDetail> getList(int id); Future<Set<int>> allListIds();}` (thin wrapper over the generated client, faked in tests); `ListsRepository` with local-first `createList`, `renameList`, `deleteList`, `addItem`, `updateItem`, `deleteItem` (each writes rows and an outbox op in ONE transaction); `SyncCoordinator.run()` single-flight (a second call while running awaits the first), triggered on start, resume, sign-in, connectivity regained, and manual refresh.

- [ ] **Step 1: Write failing tests** (in-memory DB, fake `ListsApi` with scripted failures, fake clock). Ordering and merge: `test_ops_run_fifo_one_at_a_time`; `test_ops_for_a_list_wait_for_its_create_then_use_server_id`; `test_consecutive_item_updates_merge`; `test_create_then_delete_before_sync_cancels_both_and_sends_nothing`. Failures: `test_network_error_stops_queue_and_keeps_ops`; `test_5xx_backs_off_and_retries`; `test_400_drops_op_and_reverts_row_from_server_on_next_pull`; `test_404_drops_op_and_removes_local_row`. Pull: `test_pull_uses_updated_since_and_all_cursor_pages`; `test_pull_never_overwrites_dirty_rows`; `test_pull_replaces_clean_rows_with_server_values`; `test_pull_overlap_buffer_is_deduplicated` (re-pulling a row already stored changes nothing); **`test_wrong_device_clock_does_not_affect_sync`** — fake clock at year 2000 and 2040, the stored `lists_last_pull` is always the max SERVER `updated_at` (Review Focus). Reconcile: `test_reconcile_removes_lists_missing_on_server_unless_pending_ops`. Interrupted work (Review Focus): `test_killed_mid_create_list_adopts_server_list_instead_of_duplicating` (an `inFlight` create op at startup triggers a pull first; a server list with the same name created after the op was queued is adopted and linked); `test_killed_mid_create_item_adopts_matching_item`; `test_inflight_update_and_delete_are_simply_resent`; `test_inflight_ops_reset_to_pending_on_startup_and_no_op_is_lost`; `test_no_server_match_resends_the_create_once`. Concurrency: `test_sync_coordinator_is_single_flight`; `test_sync_does_nothing_for_guest_and_stops_when_signed_out_midway`. Local ids: `test_local_uuid_to_server_id_mapping_survives_restart`.
- [ ] **Step 2: Run** `flutter test test/core/sync`. Expected: FAIL.
- [ ] **Step 3: Implement.** `lists_last_pull` = max server `updated_at` seen; pulls use it minus a 2 s buffer and dedupe by upsert; backoff doubles from 2 s to a 5 min cap; all timestamps compared come from the server.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): shopping list outbox and sync engine`.

---

### Task 14: Lists tab UI

**Files:**
- Create: `app/lib/features/lists/{state/lists_controller,ui/lists_screen,ui/list_detail_screen,ui/add_item_sheet,ui/add_to_list_sheet,ui/sync_status_chip}.dart`, tests under `app/test/features/lists/`
- Modify: `app/lib/features/offers/ui/offers_home_screen.dart` (supply `onAddToList` to `OfferDetailSheet`), `app/lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: Task 13 `ListsRepository`, Task 8 `requireSignIn`, Task 10 sheet.
- Produces: `AddToListSheet` (pick or create a list, then add the offer's product as an item); `SyncStatusChip` showing `Hors ligne`, `N en attente` or nothing.

- [ ] **Step 1: Write failing tests.** Guest sees the sign-in prompt and no list data; signed-in empty state; create a list offline and it appears instantly with the chip `1 en attente`; ticking an item moves it below unchecked items; quantity stepper stays within 1-999; swipe-delete shows an undo snackbar and undo cancels the pending delete op; adding free text and adding from an offer both work offline; offer detail `Ajouter à une liste` as guest opens sign-in then continues to the sheet; the chip clears after the fake sync succeeds; field errors from a rejected op show a French message; large text scale does not overflow; a golden for the list detail screen.
- [ ] **Step 2: Run** `flutter test test/features/lists`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): shopping lists tab`.

---

### Task 15: Loyalty card and account

**Files:**
- Create: `app/lib/features/card/{data/card_repository,ui/card_screen}.dart`, `app/lib/core/device/screen_controller.dart`, `app/lib/features/account/ui/{account_screen,edit_name_sheet,delete_account_dialog,unsynced_warning_dialog}.dart`, tests under `app/test/features/card/` and `app/test/features/account/`

**Interfaces:**
- Produces: `abstract class ScreenController {Future<void> boostBrightness(); Future<void> restoreBrightness(); Future<void> keepAwake(bool on);}` (real implementation with `screen_brightness`/`wakelock_plus`, fake in tests); `CardRepository.refresh()` (after sign-in and on start when online) and `Stream<CardRow?> watchCard()`; the card screen renders `barcodeValue` as Code 128 with a QR toggle.

- [ ] **Step 1: Write failing tests.** Guest sees the sign-in prompt on the Account tab; signed-in card screen shows the number, barcode and QR toggle; opening boosts brightness and keeps the screen awake and leaving (including via error) restores both; the card works offline from cache; edit name sends `PATCH /me` and shows server field errors; sign out with N pending ops shows the warning with N and offers `Synchroniser d'abord` or `Abandonner`; delete account asks confirmation, calls `DELETE /me`, wipes everything including `last_user_id`, returns to guest and the router lands on Offers; `Payer par mobile money` opens `/pay`; **account switch** (Review Focus): user A with lists, a card and pending outbox ops signs out choosing discard, user B signs in and sees no lists, no ops and a different card; and the same result when B signs in directly after A's session expired.
- [ ] **Step 2: Run** `flutter test test/features/card test/features/account`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): loyalty card and account screens`.

---

### Task 16: End-to-end test, CI completion and release docs

**Files:**
- Create: `app/integration_test/offline_list_sync_test.dart`, `app/lib/core/api/network_gate.dart` (test seam)
- Modify: `.github/workflows/ci.yml` (Android debug build step), `README.md` (running the app, environments, generated client, release checklist), `docs/follow-ups.md`

**Interfaces:**
- Produces: `NetworkGate` (a Dio interceptor that can simulate offline in integration tests; inert in release builds).

- [ ] **Step 1: Write the integration test** (against the real backend started with `docker compose up -d db`, migrations and `seed_demo`): sign in as `customer@example.com`; with the gate closed create a list and add an item; assert the UI shows `1 en attente` (two with the item); open the gate; wait for the chip to clear; verify through a direct API call that the list and item exist on the server; open the Pay screen and assert the three seeded providers and the checked time are shown.
- [ ] **Step 2: Run** `cd app && flutter test integration_test/offline_list_sync_test.dart -d <simulator id> --dart-define-from-file=env/dev.json`. Expected: PASS (document the exact command used).
- [ ] **Step 3: Finish CI and docs.** CI builds a debug APK; README documents environments, running on both platforms, regenerating the client, the Flutter version pin and the release checklist (signing keys, Play and App Store listings, privacy policy URL, data-safety and privacy forms, the account-deletion disclosure). Add to `docs/follow-ups.md`: server idempotency key for list creation, deletion tombstones for sync, provider app shortcuts, barcode symbology confirmation with the retailer's POS team, per-store payment numbers, staff mode.
- [ ] **Step 4: Verify everything:** `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, `tool/check_api_drift.sh`, backend full suite and drift tests. Expected: all PASS.
- [ ] **Step 5: Commit** `test(app): offline list sync e2e, CI build and release docs`.

---

## Self-Review

- **Spec coverage:** payments app, audit, step-up, throttle, French and XOF (Tasks 1-3); architecture layers and modules (4-9); screens and navigation (8, 10, 11, 12, 14, 15); data and sync (7, 10, 13); payment feature including stale-number safeguards (12); design system and accessibility (6, 10); tooling, environments, client generation, JDK (4, 5); testing, CI, release checklist (4, 5, 16). Staff mode is a separate spec and is not in this plan.
- **Types:** `formatCiPhone`/`ciPhoneForCopy`, `requireSignIn`, `SessionController`, `ListsApi`, `ListsRepository`, `OfferDetailSheet.onAddToList` and `PaymentRepository.refresh` are defined once and used by the same names later.
- **Review Focus:** each line is pinned by a named test in the owning task.
