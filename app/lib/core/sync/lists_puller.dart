import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../api/paging.dart';
import '../db/app_database.dart';
import '../db/daos/sync_meta_keys.dart' as keys;
import '../errors/app_error.dart';
import '../util/clock.dart';
import 'lists_api.dart';
import 'outbox_repository.dart';
import 'server_time.dart';

const pullOverlap = Duration(seconds: 2);

/// Pulls lists changed on the server. Only SERVER timestamps decide what is
/// fetched: `updated_since` is the stored server stamp minus a small overlap,
/// and the stored stamp becomes the maximum server `updated_at` seen.
class ListsPuller {
  ListsPuller({
    required AppDatabase db,
    required ListsApi api,
    required Clock clock,
  })  : _db = db,
        _api = api,
        _clock = clock;

  final AppDatabase _db;
  final ListsApi _api;
  final Clock _clock;

  static const _uuid = Uuid();

  /// Throws [AppError] when the server cannot be reached; the stored stamp
  /// is then untouched.
  Future<void> pull({required bool Function() isActive}) async {
    final last = await _db.syncMetaDao.get(keys.listsLastPull);
    final since = last == null
        ? null
        : formatServerInstant(parseServerInstant(last).subtract(pullOverlap));
    final summaries = await fetchAllPages<RemoteList>(
      (c) => _api.listLists(updatedSince: since, cursor: c),
    );

    // Lists whose last local write was refused are re-fetched even though
    // the server did not change them.
    final ids = <int>{
      for (final s in summaries) s.id,
      for (final l in await _db.listsDao.allLists())
        if (l.remoteId != null &&
            l.serverUpdatedAt == null &&
            !l.deletedLocally)
          l.remoteId!,
    };

    for (final id in ids) {
      if (!isActive()) return;
      final local = await _db.listsDao.byRemoteId(id);
      if (local != null && local.deletedLocally) continue;
      final RemoteListDetail detail;
      try {
        detail = await _api.getList(id);
      } on ApiError catch (e) {
        if (e.status == 404) continue; // deleted meanwhile; reconcile decides
        rethrow;
      }
      await _db.transaction(() async {
        if (!isActive()) return;
        await _apply(detail);
      });
    }

    if (!isActive()) return;
    String? max;
    for (final s in summaries) {
      max = laterServerStamp(max, s.updatedAt);
    }
    if (max != null) {
      await _db.syncMetaDao
          .set(keys.listsLastPull, laterServerStamp(last, max));
    }
  }

  Future<void> _apply(RemoteListDetail detail) async {
    final dao = _db.listsDao;
    final now = _clock().toUtc().toIso8601String();
    var local = await dao.byRemoteId(detail.list.id);
    if (local != null && local.deletedLocally) return;
    if (local == null) {
      local = ShoppingListRow(
        localId: _uuid.v4(),
        remoteId: detail.list.id,
        name: detail.list.name,
        serverUpdatedAt: detail.list.updatedAt,
        createdAt: detail.list.createdAt ?? now,
        dirty: false,
        deletedLocally: false,
      );
      await dao.upsertList(local);
    } else {
      final ops = await _db.outboxDao.opsOfList(local.localId);
      final busy = ops.any((o) => OpType.listLevel.contains(o.opType));
      if (!local.dirty && !busy) {
        await dao.upsertList(local.copyWith(
          name: detail.list.name,
          serverUpdatedAt: Value(detail.list.updatedAt),
        ));
      }
    }

    final existing = await dao.itemsOf(local.localId);
    final byRemote = {
      for (final i in existing)
        if (i.remoteId != null) i.remoteId!: i,
    };
    // Items a queued delete is about to remove must not come back.
    final deleting = <int>{
      for (final o in await _db.outboxDao.opsOfList(local.localId))
        if (o.opType == OpType.deleteItem &&
            (jsonDecode(o.payloadJson) as Map)['remoteItemId'] is int)
          (jsonDecode(o.payloadJson) as Map)['remoteItemId'] as int,
    };
    final serverIds = {for (final s in detail.items) s.id};

    for (final s in detail.items) {
      if (deleting.contains(s.id)) continue;
      final mine = byRemote[s.id];
      if (mine != null && mine.dirty) continue;
      await dao.upsertItem(ListItemRow(
        localId: mine?.localId ?? _uuid.v4(),
        listLocalId: local.localId,
        remoteId: s.id,
        productId: s.productId,
        productName: s.productName,
        productUnit: s.productUnit,
        productImageUrl: s.productImageUrl,
        itemText: s.text,
        quantity: s.quantity,
        checked: s.checked,
        dirty: false,
        createdAt: mine?.createdAt ?? s.createdAt ?? now,
      ));
    }
    for (final i in existing) {
      if (i.remoteId != null && !i.dirty && !serverIds.contains(i.remoteId)) {
        await dao.deleteItem(i.localId);
      }
    }
  }
}
