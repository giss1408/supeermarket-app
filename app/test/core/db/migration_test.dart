import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';

import '../../generated_migrations/schema.dart';

/// Scaffold for future migrations: regenerate `test/generated_migrations/`
/// with `dart run drift_dev schema generate lib/core/db/drift_schemas
/// test/generated_migrations/` after each `schema dump`, then add
/// `verifier.migrateAndValidate(...)` tests from the previous version.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database at v1 matches the schema dump', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });
}
