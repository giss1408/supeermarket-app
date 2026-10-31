import '../db/app_database.dart';
import '../errors/app_error.dart';
import 'lists_api.dart';

/// Removes local lists the server no longer has.
class ListsReconciler {
  ListsReconciler({required AppDatabase db, required ListsApi api})
      : _db = db,
        _api = api;

  final AppDatabase _db;
  final ListsApi _api;

  Future<void> reconcile({required bool Function() isActive}) async {
    final Set<int> serverIds;
    try {
      serverIds = await _api.allListIds();
    } on AppError {
      return; // never delete on partial knowledge
    } on StateError {
      return; // page cap hit
    }
    await _db.transaction(() async {
      if (!isActive()) return;
      for (final l in await _db.listsDao.allLists()) {
        final remote = l.remoteId;
        if (remote == null || serverIds.contains(remote)) continue;
        final ops = await _db.outboxDao.opsOfList(l.localId);
        if (l.deletedLocally) {
          // Already gone on the server: finish the delete.
          await _db.outboxDao.deleteByList(l.localId);
          await _db.listsDao.deleteList(l.localId);
        } else if (!l.dirty && ops.isEmpty) {
          await _db.listsDao.deleteList(l.localId);
        }
      }
    });
  }
}
