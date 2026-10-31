import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../util/clock.dart';

/// Operation types stored in `outbox_ops.op_type`.
abstract final class OpType {
  static const createList = 'createList';
  static const renameList = 'renameList';
  static const deleteList = 'deleteList';
  static const createItem = 'createItem';
  static const updateItem = 'updateItem';
  static const deleteItem = 'deleteItem';

  static const listLevel = {createList, renameList, deleteList};
  static bool isCreate(String t) => t == createList || t == createItem;
}

Map<String, dynamic> decodePayload(OutboxOpRow op) =>
    (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();

String encodePayload(Map<String, dynamic> p) => jsonEncode(p);

/// Local-first writes: every method changes the rows AND the outbox in ONE
/// transaction. Merge/fold/cancel rules only ever touch `pending` ops; an
/// `inFlight` op may be mid-send, so a new op is appended after it instead.
class OutboxRepository {
  OutboxRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  String _now() => _clock().toUtc().toIso8601String();

  OutboxOpRow? _pending(List<OutboxOpRow> ops, String type) {
    for (final o in ops.reversed) {
      if (o.state == 'pending' && o.opType == type) return o;
    }
    return null;
  }

  /// A create that was never sent. A create flagged `adopt` may already be on
  /// the server (timeout / kill): it is never folded into nor cancelled, later
  /// edits queue behind it as separate ops.
  OutboxOpRow? _unsentCreate(List<OutboxOpRow> ops, String type) {
    final o = _pending(ops, type);
    return o != null && decodePayload(o)['adopt'] != true ? o : null;
  }

  /// Drops pending ops except creates that may already exist on the server.
  Future<void> _dropPending(List<OutboxOpRow> ops) async {
    for (final o in ops) {
      if (o.state != 'pending') continue;
      if (OpType.isCreate(o.opType) && decodePayload(o)['adopt'] == true) {
        continue;
      }
      await _db.outboxDao.delete(o.id);
    }
  }

  Future<void> _enqueue(
    String type,
    String listLocalId,
    Map<String, dynamic> payload, {
    String? itemLocalId,
  }) =>
      _db.outboxDao.enqueue(
        OutboxOpsCompanion.insert(
          opType: type,
          listLocalId: listLocalId,
          itemLocalId: Value(itemLocalId),
          payloadJson: encodePayload(payload),
          createdAt: _now(),
        ),
      );

  Future<void> createList(ShoppingListRow row) => _db.transaction(() async {
        await _db.listsDao.upsertList(row);
        await _enqueue(OpType.createList, row.localId, {'name': row.name});
      });

  Future<void> renameList(String localId, String name) =>
      _db.transaction(() async {
        final list = await _db.listsDao.listByLocalId(localId);
        if (list == null || list.deletedLocally) return;
        await _db.listsDao.upsertList(list.copyWith(name: name, dirty: true));
        final ops = await _db.outboxDao.opsOfList(localId);
        final create = _unsentCreate(ops, OpType.createList);
        if (create != null) {
          await _db.outboxDao.updatePayload(create.id,
              encodePayload({...decodePayload(create), 'name': name}));
          return;
        }
        final rename = _pending(ops, OpType.renameList);
        if (rename != null) {
          await _db.outboxDao
              .updatePayload(rename.id, encodePayload({'name': name}));
          return;
        }
        await _enqueue(OpType.renameList, localId, {'name': name});
      });

  Future<void> deleteList(String localId) => _db.transaction(() async {
        final list = await _db.listsDao.listByLocalId(localId);
        if (list == null) return;
        final ops = await _db.outboxDao.opsOfList(localId);
        if (_unsentCreate(ops, OpType.createList) != null) {
          // The server never heard of it: cancel everything, send nothing.
          await _db.outboxDao.deleteByList(localId, pendingOnly: true);
          await _db.listsDao.deleteList(localId);
          return;
        }
        // The server cascades to the items; their queued ops are pointless.
        // An ambiguous create stays: the delete resolves the server id after
        // it (the row keeps its place, hidden by deletedLocally).
        await _dropPending(ops);
        await _db.listsDao.setListDeletedLocally(localId, deleted: true);
        await _db.listsDao.setListDirty(localId, dirty: true);
        await _enqueue(
            OpType.deleteList, localId, {'remoteListId': list.remoteId});
      });

  Future<void> addItem(ListItemRow row) => _db.transaction(() async {
        await _db.listsDao.upsertItem(row);
        await _enqueue(
          OpType.createItem,
          row.listLocalId,
          {
            'productId': row.productId,
            'text': row.itemText,
            'quantity': row.quantity,
            'checked': row.checked,
          },
          itemLocalId: row.localId,
        );
      });

  Future<void> updateItem(
    String itemLocalId, {
    int? quantity,
    bool? checked,
    String? text,
  }) =>
      _db.transaction(() async {
        final item = await _db.listsDao.itemByLocalId(itemLocalId);
        if (item == null) return;
        final delta = <String, dynamic>{
          if (quantity != null) 'quantity': quantity,
          if (checked != null) 'checked': checked,
          if (text != null) 'text': text,
        };
        if (delta.isEmpty) return;
        await _db.listsDao.upsertItem(item.copyWith(
          quantity: quantity ?? item.quantity,
          checked: checked ?? item.checked,
          itemText: text ?? item.itemText,
          dirty: true,
        ));
        final ops = await _db.outboxDao.opsOfItem(itemLocalId);
        // Fold into a create that has not been sent, else merge into the
        // last unsent update (latest value per field wins).
        final target = _unsentCreate(ops, OpType.createItem) ??
            _pending(ops, OpType.updateItem);
        if (target != null) {
          await _db.outboxDao.updatePayload(
            target.id,
            encodePayload({...decodePayload(target), ...delta}),
          );
          return;
        }
        await _enqueue(OpType.updateItem, item.listLocalId, delta,
            itemLocalId: itemLocalId);
      });

  Future<void> deleteItem(String itemLocalId) => _db.transaction(() async {
        final item = await _db.listsDao.itemByLocalId(itemLocalId);
        if (item == null) return;
        final ops = await _db.outboxDao.opsOfItem(itemLocalId);
        if (_unsentCreate(ops, OpType.createItem) != null) {
          await _db.outboxDao.deleteByItem(itemLocalId, pendingOnly: true);
          await _db.listsDao.deleteItem(itemLocalId);
          return;
        }
        await _dropPending(ops);
        if (item.remoteId == null) {
          // Its create is mid-send or ambiguous: keep the row so the push can
          // resolve the server id once the create is linked, then delete it.
          await _enqueue(OpType.deleteItem, item.listLocalId, {},
              itemLocalId: itemLocalId);
          return;
        }
        final list = await _db.listsDao.listByLocalId(item.listLocalId);
        await _db.listsDao.deleteItem(itemLocalId);
        await _enqueue(
          OpType.deleteItem,
          item.listLocalId,
          {'remoteListId': list?.remoteId, 'remoteItemId': item.remoteId},
          itemLocalId: itemLocalId,
        );
      });

  /// Crash recovery: an op left `inFlight` was interrupted. It goes back to
  /// `pending`; a create is flagged `adopt` because the server may already
  /// have created the resource (creates are not idempotent).
  Future<void> recoverInterrupted() => _db.transaction(() async {
        for (final op in await _db.outboxDao.inFlight()) {
          if (OpType.isCreate(op.opType)) {
            await _db.outboxDao.updatePayload(
              op.id,
              encodePayload({...decodePayload(op), 'adopt': true}),
            );
          }
          await _db.outboxDao.setState(op.id, 'pending');
        }
      });

  /// Clears `dirty` on the touched rows when no op references them anymore.
  Future<void> refreshDirty(String listLocalId, String? itemLocalId) async {
    final ops = await _db.outboxDao.opsOfList(listLocalId);
    if (await _db.listsDao.listByLocalId(listLocalId) != null) {
      final listBusy = ops.any((o) => OpType.listLevel.contains(o.opType));
      if (!listBusy) {
        await _db.listsDao.setListDirty(listLocalId, dirty: false);
      }
    }
    if (itemLocalId != null &&
        await _db.listsDao.itemByLocalId(itemLocalId) != null &&
        !ops.any((o) => o.itemLocalId == itemLocalId)) {
      await _db.listsDao.setItemDirty(itemLocalId, dirty: false);
    }
  }
}
