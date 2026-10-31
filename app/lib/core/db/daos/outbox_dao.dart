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

  Future<OutboxOpRow?> byId(int id) =>
      (_db.select(_db.outboxOps)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> updatePayload(int id, String payloadJson) =>
      (_db.update(_db.outboxOps)..where((t) => t.id.equals(id)))
          .write(OutboxOpsCompanion(payloadJson: Value(payloadJson)));

  /// Ops of a list (its own and its items'), oldest first.
  Future<List<OutboxOpRow>> opsOfList(String listLocalId) =>
      (_db.select(_db.outboxOps)
            ..where((t) => t.listLocalId.equals(listLocalId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<List<OutboxOpRow>> opsOfItem(String itemLocalId) =>
      (_db.select(_db.outboxOps)
            ..where((t) => t.itemLocalId.equals(itemLocalId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<List<OutboxOpRow>> inFlight() => (_db.select(_db.outboxOps)
        ..where((t) => t.state.equals('inFlight'))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();

  /// Deletes every op of a list (and of its items); `pendingOnly` keeps ops
  /// that may be mid-send.
  Future<void> deleteByList(String listLocalId, {bool pendingOnly = false}) =>
      (_db.delete(_db.outboxOps)
            ..where((t) =>
                t.listLocalId.equals(listLocalId) &
                (pendingOnly
                    ? t.state.equals('pending')
                    : const Constant(true))))
          .go();

  Future<void> deleteByItem(String itemLocalId, {bool pendingOnly = false}) =>
      (_db.delete(_db.outboxOps)
            ..where((t) =>
                t.itemLocalId.equals(itemLocalId) &
                (pendingOnly
                    ? t.state.equals('pending')
                    : const Constant(true))))
          .go();
}
