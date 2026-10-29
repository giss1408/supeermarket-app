import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sync_meta_dao.g.dart';

@DriftAccessor(tables: [SyncMeta])
class SyncMetaDao extends DatabaseAccessor<AppDatabase>
    with _$SyncMetaDaoMixin {
  SyncMetaDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(syncMeta)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      into(syncMeta).insertOnConflictUpdate(
        SyncMetaCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (delete(syncMeta)..where((t) => t.key.equals(key))).go();
}
