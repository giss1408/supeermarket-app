import 'package:drift/drift.dart';

import '../app_database.dart';

/// Plain class (not a `DatabaseAccessor`): the required `delete(int id)` would
/// clash with `DatabaseConnectionUser.delete`.
class OutboxDao {
  OutboxDao(this._db);

  final AppDatabase _db;

  static const _active = ['pending', 'inFlight'];

  Future<int> enqueue(OutboxOpsCompanion op) =>
      _db.into(_db.outboxOps).insert(op);

  Future<List<OutboxOpRow>> pendingInOrder() => (_db.select(_db.outboxOps)
        ..where((t) => t.state.isIn(_active))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();

  Future<void> setState(int id, String state, {String? error}) async {
    final bump = state == 'inFlight' || state == 'failed';
    await _db.customUpdate(
      'UPDATE outbox_ops SET state = ?, last_error = ?, '
      'attempts = attempts + ? WHERE id = ?',
      variables: [
        Variable<String>(state),
        Variable<String>(error),
        Variable<int>(bump ? 1 : 0),
        Variable<int>(id),
      ],
      updates: {_db.outboxOps},
    );
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.outboxOps)..where((t) => t.id.equals(id))).go();

  Selectable<int> get _count {
    final count = _db.outboxOps.id.count();
    return (_db.selectOnly(_db.outboxOps)
          ..addColumns([count])
          ..where(_db.outboxOps.state.isIn(_active)))
        .map((r) => r.read(count) ?? 0);
  }

  Future<int> pendingCount() => _count.getSingle();

  Stream<int> watchPendingCount() => _count.watchSingle();

  Future<void> resetInFlightToPending() =>
      (_db.update(_db.outboxOps)..where((t) => t.state.equals('inFlight')))
          .write(const OutboxOpsCompanion(state: Value('pending')));
}
