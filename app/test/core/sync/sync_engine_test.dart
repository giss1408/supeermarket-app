import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/sync/lists_puller.dart';
import 'package:supermarket_app/core/sync/lists_reconciler.dart';
import 'package:supermarket_app/core/sync/server_time.dart';

import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/sync/sync_coordinator.dart'
    show backoffDelay;

import '../../support/fake_lists_api.dart';
import '../../support/sync_harness.dart';
import '../db/test_db.dart';

Map<String, dynamic> payload(OutboxOpRow op) =>
    jsonDecode(op.payloadJson) as Map<String, dynamic>;

void main() {
  test('ops_run_fifo_one_at_a_time_and_server_ids_are_mapped', () async {
    final h = SyncHarness();
    final list = await h.repo.createList('Courses');
    final item = await h.repo.addItem(list, text: 'Pain', quantity: 2);
    await h.repo.renameList(list, 'Marché'); // folds into the pending create
    await h.sync();
    expect(h.api.writes, ['createList:Marché', 'createItem:1:Pain:2']);
    expect(h.api.maxConcurrent, 1);

    final l = (await h.lists()).single;
    final i = (await h.items()).single;
    expect([l.localId, l.remoteId, l.dirty], [list, 1, false]);
    expect(l.serverUpdatedAt, isNotNull);
    expect([i.localId, i.remoteId, i.dirty], [item, 1, false]);
    expect(await h.ops(), isEmpty);

    await h.repo.renameList(list, 'Final'); // synced now: a real rename op
    await h.repo.updateItem(item, checked: true);
    await h.sync();
    expect(h.api.writes.skip(2), [
      'renameList:1:Final',
      'updateItem:1:1:-:true:-',
    ]);
  });

  test('merge_and_cancel_rules', () async {
    final h = SyncHarness();
    final list = await h.repo.createList('Courses');
    final item = await h.repo.addItem(list, text: 'Pain');
    // Update before the create was sent folds into the create.
    await h.repo.updateItem(item, quantity: 5);
    var ops = await h.ops();
    expect(ops.map((o) => o.opType), ['createList', 'createItem']);
    expect(payload(ops.last)['quantity'], 5);
    await h.sync();

    // Consecutive updates of a synced item merge (latest per field wins).
    await h.repo.updateItem(item, quantity: 2);
    await h.repo.updateItem(item, checked: true);
    await h.repo.updateItem(item, quantity: 3);
    ops = await h.ops();
    expect(ops, hasLength(1));
    expect(payload(ops.single), {'quantity': 3, 'checked': true});

    // Create then delete before sync sends nothing and leaves nothing.
    final tmp = await h.repo.addItem(list, text: 'Lait');
    await h.repo.deleteItem(tmp);
    expect((await h.items()).map((i) => i.localId), [item]);
    final scratch = await h.repo.createList('Brouillon');
    await h.repo.addItem(scratch, text: 'x');
    await h.repo.deleteList(scratch);
    expect((await h.lists()).map((l) => l.localId), [list]);
    expect((await h.ops()).map((o) => o.opType), ['updateItem']);
    final before = h.api.writes.length;
    await h.sync();
    expect(h.api.writes.skip(before), ['updateItem:1:1:3:true:-']);

    // Deleting a synced list hides it, drops item ops and sends one delete.
    await h.repo.updateItem(item, quantity: 9);
    await h.repo.deleteList(list);
    expect((await h.ops()).map((o) => o.opType), ['deleteList']);
    expect((await h.lists()).single.deletedLocally, isTrue);
    await h.sync();
    expect(h.api.writes.last, 'deleteList:1');
    expect(await h.lists(), isEmpty);
  });

  test('network_error_keeps_ops_and_stops_the_queue_and_5xx_too', () async {
    for (final error in <AppError>[const NetworkError(), apiError(503)]) {
      final h = SyncHarness();
      final a = await h.repo.createList('A');
      await h.repo.createList('B');
      h.api.failNext('createList', error);
      await h.sync();
      expect(h.api.writes, ['createList:A'], reason: 'B must not be tried');
      expect(h.api.count('listLists'), 0, reason: 'no pull while stuck');
      var ops = await h.ops();
      expect(ops.map((o) => o.state), ['pending', 'pending']);
      expect(payload(ops.first)['adopt'], isTrue); // ambiguous create
      expect(ops.first.lastError, isNotNull);

      await h.sync(); // network back: adoption check finds nothing, then sends
      expect(h.api.writes, ['createList:A', 'createList:A', 'createList:B']);
      expect(h.api.listCount, 2);
      expect((await h.lists()).every((l) => l.remoteId != null), isTrue);
      expect((await h.lists()).first.localId, isNotEmpty);
      expect(a, isNotEmpty);
    }
    expect(backoffDelayCheck, returnsNormally);
  });

  test(
      '400_drops_the_op_and_reverts_the_row_on_next_pull_and_emits_a_rejection',
      () async {
    final h = SyncHarness();
    final list = await h.repo.createList('Courses');
    await h.sync();
    await h.repo.renameList(list, 'Refusé');
    h.api.failNext('renameList', apiError(400));
    await h.sync();
    expect(await h.ops(), isEmpty);
    expect(h.rejections.map((r) => (r.opType, r.listLocalId)),
        [('renameList', list)]);
    // The pull of the same run restored the server's value.
    final l = (await h.lists()).single;
    expect([l.name, l.dirty], ['Courses', false]);

    // A never-synced row is deleted with its dependents.
    final bad = await h.repo.createList('Mauvais');
    await h.repo.addItem(bad, text: 'x');
    h.api.failNext('createList', apiError(400));
    await h.sync();
    expect((await h.lists()).map((l) => l.localId), [list]);
    expect(await h.items(), isEmpty);
    expect(await h.ops(), isEmpty);
    expect(h.rejections, hasLength(2));
    expect(h.api.writes.where((w) => w.startsWith('createItem')), isEmpty);
  });

  test('404_drops_the_op_and_removes_the_row_and_404_on_delete_is_success',
      () async {
    final h = SyncHarness();
    final list = await h.repo.createList('Courses');
    final item = await h.repo.addItem(list, text: 'Pain');
    final other = await h.repo.addItem(list, text: 'Lait');
    await h.sync();
    await h.repo.updateItem(item, checked: true);
    h.api.dropItemOnServer(1, 1);
    await h.sync(); // updateItem answers 404
    expect((await h.items()).map((i) => i.localId), [other]);
    expect(await h.ops(), isEmpty);
    expect(h.rejections, isEmpty);

    await h.repo.deleteItem(other);
    h.api.dropItemOnServer(1, 2); // already deleted elsewhere
    await h.sync();
    expect(await h.items(), isEmpty);
    expect(await h.ops(), isEmpty);

    await h.repo.renameList(list, 'Renommée');
    h.api.dropListOnServer(1);
    await h.sync(); // renameList answers 404: the list is gone
    expect(await h.lists(), isEmpty);

    final l2 = await h.repo.createList('Autre');
    await h.sync();
    await h.repo.deleteList(l2);
    h.api.dropListOnServer(2);
    await h.sync(); // deleteList answers 404 = success
    expect(await h.lists(), isEmpty);
    expect(await h.ops(), isEmpty);
    expect(h.rejections, isEmpty);
  });

  test(
      'pull_uses_updated_since_with_overlap_and_all_pages_and_never_overwrites_dirty_rows',
      () async {
    final h = SyncHarness();
    h.api.pageSize = 2;
    final mine = await h.repo.createList('Courses');
    final item = await h.repo.addItem(mine, text: 'Pain');
    await h.sync();
    final clean = h.api.seedList('Serveur');
    final other = h.api.seedList('Autre');
    h.api.seedList('Troisième');
    final stored = (await h.lastPull())!;

    // Local edits not yet pushed + concurrent server edits.
    await h.repo.renameList(mine, 'Locale');
    await h.repo.updateItem(item, checked: true);
    h.api.renameOnServer(1, 'Serveur-1');
    h.api.setItemOnServer(1, 1, checked: false);
    h.api.seedItem(1, text: 'Œufs');
    h.api.renameOnServer(clean, 'Serveur-2');

    h.api.calls.clear();
    final puller = ListsPuller(db: h.db, api: h.api, clock: () => h.now);
    await puller.pull(isActive: () => true);
    final since = formatServerInstant(
        parseServerInstant(stored).subtract(const Duration(seconds: 2)));
    expect(h.api.calls.where((c) => c.startsWith('listLists')),
        ['listLists:$since:-', 'listLists:$since:2']);

    final byRemote = {for (final l in await h.lists()) l.remoteId: l};
    expect(byRemote[1]!.name, 'Locale'); // dirty list untouched
    expect(byRemote[clean]!.name, 'Serveur-2'); // clean list replaced
    expect(byRemote[other], isNotNull); // new list inserted
    final items = await h.items();
    expect(items.firstWhere((i) => i.localId == item).checked, isTrue);
    expect(items.map((i) => i.itemText), containsAll(['Pain', 'Œufs']));

    // The overlap re-delivers rows: applying again changes nothing.
    final rowsBefore = (await h.lists()).length;
    final itemsBefore = (await h.items()).length;
    await puller.pull(isActive: () => true);
    expect([(await h.lists()).length, (await h.items()).length],
        [rowsBefore, itemsBefore]);
    expect(await h.lastPull(), isNotNull);
  });

  test('server_timestamps_only_wrong_device_clock_changes_nothing', () async {
    Future<(List<String>, String?, List<String>)> scenario(DateTime now) async {
      final h = SyncHarness(now: now);
      final other = h.api.seedList('Autre appareil');
      final first = await h.repo.createList('Courses');
      await h.repo.addItem(first, text: 'Pain');
      await h.sync();
      // A create interrupted mid-flight; the server did get it afterwards.
      await h.repo.createList('Fête');
      final op = (await h.ops()).single;
      await h.db.outboxDao.setState(op.id, 'inFlight');
      h.api.seedList('Fête');
      h.api.renameOnServer(other, 'Autre renommée');
      await h.sync();
      final names = [for (final l in await h.lists()) l.name]..sort();
      // The stored stamp is exactly the server's newest updated_at.
      expect(await h.lastPull(), h.api.latestStamp());
      return (h.api.calls, await h.lastPull(), names);
    }

    final y2000 = await scenario(DateTime.utc(2000));
    final y2040 = await scenario(DateTime.utc(2040));
    expect(y2000.$1, y2040.$1); // identical requests
    expect(y2000.$2, y2040.$2);
    expect(y2000.$3, y2040.$3);
    expect(y2000.$3, ['Autre renommée', 'Courses', 'Fête']);
    expect(y2000.$1.where((c) => c.startsWith('createList:Fête')), isEmpty);
  });

  test('reconcile_removes_lists_missing_on_the_server_unless_dirty_or_unsynced',
      () async {
    final h = SyncHarness();
    final api = h.api..seedList('Existe');
    final dao = h.db.listsDao;
    Future<void> seed(String id,
            {int? remote, bool dirty = false, bool del = false}) =>
        dao.upsertList(shoppingList(id, remoteId: remote)
            .copyWith(dirty: dirty, deletedLocally: del));
    await seed('kept', remote: 1);
    await seed('gone', remote: 2);
    await dao.upsertItem(listItem('i', 'gone'));
    await seed('dirty', remote: 3, dirty: true);
    await seed('queued', remote: 4);
    await h.db.outboxDao.enqueue(OutboxOpsCompanion.insert(
      opType: 'renameList',
      listLocalId: 'queued',
      payloadJson: '{"name":"x"}',
      createdAt: '2026-10-29T10:00:00Z',
    ));
    await seed('unsynced');
    await seed('deleted', remote: 5, del: true);
    final reconciler = ListsReconciler(db: h.db, api: api);

    api.failNext('allListIds', const NetworkError());
    await reconciler.reconcile(isActive: () => true);
    expect((await h.lists()), hasLength(6), reason: 'failure deletes nothing');

    await reconciler.reconcile(isActive: () => true);
    expect(
      (await h.lists()).map((l) => l.localId).toSet(),
      {'kept', 'dirty', 'queued', 'unsynced'},
    );
    expect(await h.items(), isEmpty); // cascade
  });
}

void backoffDelayCheck() {
  expect(backoffDelay(0), const Duration(seconds: 2));
  expect(backoffDelay(3), const Duration(seconds: 16));
  expect(backoffDelay(30), const Duration(minutes: 5));
}
