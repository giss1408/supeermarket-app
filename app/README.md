# supermarket_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

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
