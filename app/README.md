# supermarket_app

Flutter customer app (Android and iOS) for the supermarket backend: offers and
flyers, stores, mobile-money payment instructions, offline-first shopping
lists, and the loyalty card. Pins: Flutter 3.24.2, Dart 3.5.2.

## Environments

The API address is a build-time define, never read at runtime. Pass one of the
files in `env/`:

| File | `API_BASE_URL` | Use |
| --- | --- | --- |
| `env/dev.json` | `http://10.0.2.2:8000` | Android emulator (10.0.2.2 is the host) |
| `env/dev_ios.json` | `http://localhost:8000` | iOS simulator |
| `env/staging.json` | `https://api.example.com` | placeholder, set the real host |
| `env/prod.json` | `https://api.example.com` | placeholder, set the real host |

    flutter run --dart-define-from-file=env/dev.json

An empty `API_BASE_URL` makes the app fail at start on purpose. A physical
phone needs the host's LAN address in a local copy of the file; do not commit
it. Never commit `.env*` files.

## Release checklist

- [ ] `staging.json` and `prod.json` hold the real HTTPS API hosts.
- [ ] `flutter analyze` and `flutter test --exclude-tags golden` pass; CI is green.
- [ ] API client is in sync with `backend/openapi.yaml` (`tool/check_api_drift.sh`).
- [ ] Barcode symbology on the loyalty card confirmed with the POS team.
- [ ] Payment numbers and wording checked with the retailer.
- [ ] Android: set `applicationId`, version and the release signing config
      (the debug key is not for release); `flutter build appbundle --dart-define-from-file=env/prod.json`.
- [ ] Android manifest: only `INTERNET` and `ACCESS_COARSE_LOCATION` remain in the
      merged manifest (`ACCESS_FINE_LOCATION` is removed with `tools:node="remove"`).
- [ ] iOS: bundle id, signing team, location usage string;
      `flutter build ipa --dart-define-from-file=env/prod.json`.
- [ ] Store listings: privacy-policy URL, account deletion path (Account tab),
      data-safety / privacy-label answers.
- [ ] Smoke test on a real device: sign in, create a list offline, go online and
      watch it sync, open the loyalty card, open a store, pay screen.
- [ ] Run `integration_test/offline_list_sync_test.dart` against a dev backend
      (it has never been run on a device):
      `flutter test integration_test/offline_list_sync_test.dart --dart-define-from-file=env/dev.json -d <device>`.

## Tests

- `flutter test --exclude-tags golden` runs the regular suite (this is what CI runs).
- Golden tests (tag `golden`, images in `test/goldens/`): run locally with
  `flutter test --tags golden`, regenerate with `flutter test --tags golden --update-goldens`.
  They are excluded in CI because text rendering differs between macOS and Linux.

## Database

Local SQLite database via Drift (`lib/core/db/`). Generated `*.g.dart` files are
git-ignored.

- Regenerate code after changing tables or DAOs:
  `dart run build_runner build --delete-conflicting-outputs`.
- When `schemaVersion` changes (see `AppDatabase`), dump the new schema and
  regenerate the migration-test helpers, then commit both:
  `dart run drift_dev schema dump lib/core/db/app_database.dart lib/core/db/drift_schemas/`
  `dart run drift_dev schema generate lib/core/db/drift_schemas test/generated_migrations/`
- Search is accent-insensitive: `registerSearchFunctions` (`lib/core/db/search_functions.dart`)
  registers the SQL function `fold_search` (lowercase and strip diacritics, same as
  `foldSearch` in Dart) on every connection, because SQLite `LIKE` only folds ASCII
  case. Any new text search must compare `fold_search(column)` with the
  Dart-folded query (use `containsFolded`), and any new `NativeDatabase` must pass
  `setup: registerSearchFunctions`.
- Tests use `NativeDatabase.memory(setup: registerSearchFunctions)` and need the system SQLite
  (`libsqlite3-dev` on Linux, as in CI).
