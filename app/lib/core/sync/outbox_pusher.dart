import '../api/paging.dart';
import '../db/app_database.dart';
import '../db/daos/sync_meta_keys.dart' as keys;
import '../errors/app_error.dart';
import 'lists_api.dart';
import 'outbox_repository.dart';
import 'server_time.dart';

export 'lists_api.dart' show ListsApi;

enum PushOutcome { done, retryLater, unauthorized, aborted }

/// A change the server refused; shown to the user by the UI.
class SyncRejection {
  const SyncRejection(this.opType, this.listLocalId, this.message);

  final String opType;
  final String listLocalId;
  final String message;
}

const _rejectedMessage = 'Le serveur a refusé cette modification.';

/// Result of sending one op: how to apply it locally.
typedef _Apply = Future<void> Function();

/// Sends the outbox strictly FIFO, one op at a time.
class OutboxPusher {
  OutboxPusher({
    required AppDatabase db,
    required ListsApi api,
    required OutboxRepository outbox,
    required void Function(SyncRejection) onRejection,
  })  : _db = db,
        _api = api,
        _outbox = outbox,
        _onRejection = onRejection;

  final AppDatabase _db;
  final ListsApi _api;
  final OutboxRepository _outbox;
  final void Function(SyncRejection) _onRejection;

  Future<PushOutcome> push({required bool Function() isActive}) async {
    while (true) {
      if (!isActive()) return PushOutcome.aborted;
      final ops = await _db.outboxDao.pendingInOrder();
      final next = ops.where((o) => o.state == 'pending').firstOrNull;
      if (next == null) return PushOutcome.done;
      final outcome = await _processOne(next.id, isActive);
      if (outcome != null) return outcome;
    }
  }

  /// Returns null to continue with the next op.
  Future<PushOutcome?> _processOne(int id, bool Function() isActive) async {
    // Re-read: the op may have been merged or cancelled since it was listed.
    final op = await _db.transaction(() async {
      final o = await _db.outboxDao.byId(id);
      if (o == null || o.state != 'pending' || !isActive()) return null;
      await _db.outboxDao.setState(id, 'inFlight');
      return o;
    });
    if (op == null) return isActive() ? null : PushOutcome.aborted;

    _Apply apply;
    try {
      apply = await _send(op);
    } on Object catch (e) {
      final error = e is AppError ? e : UnknownError(e);
      return _fail(op, error, isActive);
    }
    await _complete(op, apply, isActive);
    return null;
  }

  Future<void> _complete(
    OutboxOpRow op,
    _Apply apply,
    bool Function() isActive,
  ) =>
      _db.transaction(() async {
        // Signed out / switched user while the request flew, or the data was
        // wiped: write nothing.
        if (!isActive()) return;
        if (await _db.outboxDao.byId(op.id) == null) return;
        await apply();
        await _db.outboxDao.delete(op.id);
        await _outbox.refreshDirty(op.listLocalId, op.itemLocalId);
      });

  // ---- sending -----------------------------------------------------------

  Future<_Apply> _send(OutboxOpRow op) async {
    final p = decodePayload(op);
    final dao = _db.listsDao;
    final list = await dao.listByLocalId(op.listLocalId);
    final item = op.itemLocalId == null
        ? null
        : await dao.itemByLocalId(op.itemLocalId!);
    Future<void> nothing() async {}

    switch (op.opType) {
      case OpType.createList:
        if (list == null) return nothing;
        final name = p['name'] as String;
        if (p['adopt'] == true) {
          final adopted = await _findServerList(name);
          if (adopted != null) {
            return () => dao.setListServerIds(list.localId,
                remoteId: adopted.id, serverUpdatedAt: adopted.updatedAt);
          }
        }
        final created = await _api.createList(name);
        return () => dao.setListServerIds(list.localId,
            remoteId: created.id, serverUpdatedAt: created.updatedAt);

      case OpType.renameList:
        final remote = list?.remoteId;
        if (remote == null) return nothing;
        await _api.renameList(remote, p['name'] as String);
        return nothing;

      case OpType.deleteList:
        final remote = (p['remoteListId'] as int?) ?? list?.remoteId;
        if (remote != null) await _api.deleteList(remote);
        return () => dao.deleteList(op.listLocalId);

      case OpType.createItem:
        final listRemote = list?.remoteId;
        if (item == null || listRemote == null) return nothing;
        final payload = ItemPayload(
          productId: p['productId'] as int?,
          text: (p['text'] as String?) ?? '',
          quantity: (p['quantity'] as int?) ?? 1,
          checked: (p['checked'] as bool?) ?? false,
        );
        if (p['adopt'] == true) {
          final adopted = await _findServerItem(list!, payload);
          if (adopted != null) {
            return () => dao.setItemRemoteId(item.localId, adopted.id);
          }
        }
        final created = await _api.createItem(listRemote, payload);
        return () => dao.setItemRemoteId(item.localId, created.id);

      case OpType.updateItem:
        final listRemote = list?.remoteId;
        final itemRemote = item?.remoteId;
        if (listRemote == null || itemRemote == null) return nothing;
        await _api.updateItem(
          listRemote,
          itemRemote,
          ItemPayload(
            text: p['text'] as String?,
            quantity: p['quantity'] as int?,
            checked: p['checked'] as bool?,
          ),
        );
        return nothing;

      case OpType.deleteItem:
        final listRemote = (p['remoteListId'] as int?) ?? list?.remoteId;
        final itemRemote = (p['remoteItemId'] as int?) ?? item?.remoteId;
        if (listRemote != null && itemRemote != null) {
          await _api.deleteItem(listRemote, itemRemote);
        }
        return () async {
          if (item != null) await dao.deleteItem(item.localId);
        };
    }
    return nothing;
  }

  // ---- adoption ----------------------------------------------------------

  /// A create may already have reached the server (killed or lost answer).
  /// Looks for a server list nobody here is linked to, with exactly the name
  /// sent, changed after the last pull. Server values only.
  Future<RemoteList?> _findServerList(String name) async {
    final last = await _db.syncMetaDao.get(keys.listsLastPull);
    final summaries = await fetchAllPages<RemoteList>(
      (c) => _api.listLists(updatedSince: last, cursor: c),
    );
    final linked = {
      for (final l in await _db.listsDao.allLists())
        if (l.remoteId != null) l.remoteId!,
    };
    final lastInstant = last == null ? null : parseServerInstant(last);
    final matches = summaries.where((s) =>
        !linked.contains(s.id) &&
        s.name == name &&
        (lastInstant == null ||
            parseServerInstant(s.updatedAt).isAfter(lastInstant)));
    return _lowest(matches, (s) => s.id);
  }

  Future<RemoteItem?> _findServerItem(
    ShoppingListRow list,
    ItemPayload payload,
  ) async {
    final detail = await _api.getList(list.remoteId!);
    final local = await _db.listsDao.itemsOf(list.localId);
    final claimed = {
      for (final i in local)
        if (i.remoteId != null) i.remoteId!,
      // Items a queued delete is about to remove are not ours to adopt.
      for (final o in await _db.outboxDao.opsOfList(list.localId))
        if (o.opType == OpType.deleteItem &&
            decodePayload(o)['remoteItemId'] is int)
          decodePayload(o)['remoteItemId'] as int,
    };
    final matches = detail.items.where((s) =>
        !claimed.contains(s.id) &&
        s.productId == payload.productId &&
        s.text == (payload.text ?? '') &&
        s.quantity == payload.quantity);
    return _lowest(matches, (s) => s.id);
  }

  T? _lowest<T>(Iterable<T> items, int Function(T) id) {
    T? best;
    for (final i in items) {
      if (best == null || id(i) < id(best)) best = i;
    }
    return best;
  }

  // ---- failures ----------------------------------------------------------

  Future<PushOutcome?> _fail(
    OutboxOpRow op,
    AppError error,
    bool Function() isActive,
  ) async {
    if (error is ApiError) {
      final s = error.status;
      if (s == 401) {
        await _backToPending(op, error, adopt: false);
        return PushOutcome.unauthorized;
      }
      if (s == 404) {
        await _gone(op, isActive);
        return null;
      }
      if (s >= 400 && s < 500 && s != 429) {
        await _reject(op, error, isActive);
        return null;
      }
      // 5xx may also have been committed behind a proxy: treat like a lost
      // answer for creates.
    }
    await _backToPending(op, error, adopt: OpType.isCreate(op.opType));
    return PushOutcome.retryLater;
  }

  Future<void> _backToPending(
    OutboxOpRow op,
    AppError error, {
    required bool adopt,
  }) =>
      _db.transaction(() async {
        final cur = await _db.outboxDao.byId(op.id);
        if (cur == null) return;
        if (adopt) {
          await _db.outboxDao.updatePayload(
            op.id,
            encodePayload({...decodePayload(cur), 'adopt': true}),
          );
        }
        await _db.outboxDao.setState(op.id, 'pending', error: '$error');
      });

  /// 404: the resource is gone elsewhere. A delete is a success.
  Future<void> _gone(OutboxOpRow op, bool Function() isActive) =>
      _db.transaction(() async {
        if (!isActive() || await _db.outboxDao.byId(op.id) == null) return;
        final dao = _db.listsDao;
        switch (op.opType) {
          case OpType.deleteList:
            await _db.outboxDao.delete(op.id);
            await dao.deleteList(op.listLocalId);
            await _db.outboxDao.deleteByList(op.listLocalId);
            return;
          case OpType.deleteItem:
            await _db.outboxDao.delete(op.id);
            if (op.itemLocalId != null) await dao.deleteItem(op.itemLocalId!);
            await _outbox.refreshDirty(op.listLocalId, null);
            return;
          case OpType.createItem || OpType.updateItem:
            await _db.outboxDao.delete(op.id);
            final id = op.itemLocalId!;
            await _db.outboxDao.deleteByItem(id);
            await dao.deleteItem(id);
            // The parent may be gone too: let the next pull check it.
            await dao.setListServerUpdatedAt(op.listLocalId, null);
          default: // createList / renameList: the list itself is gone.
            await _db.outboxDao.deleteByList(op.listLocalId);
            await dao.deleteList(op.listLocalId);
        }
      });

  /// 400 and other refused requests: drop the op, restore the row from the
  /// server on the next pull and tell the UI.
  Future<void> _reject(
    OutboxOpRow op,
    ApiError error,
    bool Function() isActive,
  ) async {
    var applied = false;
    await _db.transaction(() async {
      if (!isActive() || await _db.outboxDao.byId(op.id) == null) return;
      applied = true;
      final dao = _db.listsDao;
      await _db.outboxDao.delete(op.id);
      switch (op.opType) {
        case OpType.createList:
          // Never existed on the server: dependents die with it.
          await _db.outboxDao.deleteByList(op.listLocalId);
          await dao.deleteList(op.listLocalId);
        case OpType.createItem:
          final id = op.itemLocalId!;
          await _db.outboxDao.deleteByItem(id);
          await dao.deleteItem(id);
        case OpType.renameList:
          await _revertList(op.listLocalId);
        case OpType.deleteList:
          await dao.setListDeletedLocally(op.listLocalId, deleted: false);
          await _revertList(op.listLocalId);
        case OpType.updateItem || OpType.deleteItem:
          final id = op.itemLocalId;
          if (id != null && await dao.itemByLocalId(id) != null) {
            final stillQueued = (await _db.outboxDao.opsOfItem(id)).isNotEmpty;
            if (!stillQueued) await dao.setItemDirty(id, dirty: false);
          }
          await dao.setListServerUpdatedAt(op.listLocalId, null);
      }
    });
    if (applied) {
      _onRejection(SyncRejection(
        op.opType,
        op.listLocalId,
        _messageOf(error),
      ));
    }
  }

  Future<void> _revertList(String listLocalId) async {
    final dao = _db.listsDao;
    final list = await dao.listByLocalId(listLocalId);
    if (list == null) return;
    final ops = await _db.outboxDao.opsOfList(listLocalId);
    if (!ops.any((o) => OpType.listLevel.contains(o.opType))) {
      await dao.setListDirty(listLocalId, dirty: false);
    }
    if (list.remoteId != null) {
      await dao.setListServerUpdatedAt(listLocalId, null);
    }
  }

  String _messageOf(ApiError e) {
    for (final msgs in e.fields.values) {
      if (msgs.isNotEmpty) return msgs.first;
    }
    return _rejectedMessage;
  }
}
