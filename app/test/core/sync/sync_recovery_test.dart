import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/errors/app_error.dart';

import '../../support/sync_harness.dart';

void main() {
  test('killed_mid_create_list_adopts_the_server_list_instead_of_duplicating',
      () async {
    final h = SyncHarness();
    await h.repo.createList('Courses');
    final op = (await h.ops()).single;
    await h.db.outboxDao.setState(op.id, 'inFlight'); // app killed mid-send
    // Baseline pull happened earlier; the server then created the list.
    await h.db.syncMetaDao.set('lists_last_pull', h.api.stamp(0));
    final serverId = h.api.seedList('Courses');

    await h.restart().sync();

    expect(h.api.count('createList'), 0);
    expect(h.api.listCount, 1);
    final lists = await h.lists();
    expect(lists, hasLength(1));
    expect(lists.single.remoteId, serverId);
    expect(await h.ops(), isEmpty);
  });

  test('killed_mid_create_item_adopts_the_matching_server_item', () async {
    final h = SyncHarness();
    final list = await h.repo.createList('Courses');
    await h.sync();
    final item =
        await h.repo.addItem(list, productId: null, text: 'Pain', quantity: 2);
    final op = (await h.ops()).single;
    await h.db.outboxDao.setState(op.id, 'inFlight');
    final serverItem = h.api.seedItem(1, text: 'Pain', quantity: 2);

    await h.restart().sync();

    expect(h.api.count('createItem'), 0);
    expect(h.api.itemCount(1), 1);
    final items = await h.items();
    expect(items, hasLength(1));
    expect([items.single.localId, items.single.remoteId], [item, serverItem]);
    expect(await h.ops(), isEmpty);
  });

  test('ambiguous_create_with_no_server_match_is_sent_once', () async {
    final h = SyncHarness();
    // Another device made a same-named list BEFORE our last pull: not ours.
    h.api.seedList('Courses');
    await h.sync();
    await h.repo.createList('Courses');
    final op = (await h.ops()).single;
    await h.db.outboxDao.setState(op.id, 'inFlight'); // server never saw it

    await h.restart().sync();

    expect(h.api.count('createList'), 1);
    expect(h.api.listCount, 2);
    final lists = await h.lists();
    expect(lists, hasLength(2));
    expect(lists.map((l) => l.remoteId).toSet(), {1, 2});
    expect(await h.ops(), isEmpty);

    // A create whose answer was lost (request reached the server) adopts it.
    await h.repo.createList('Fruits');
    h.api.failNext('createList', const AppTimeoutError(), applyFirst: true);
    await h.sync();
    await h.sync();
    expect(h.api.listNames().where((n) => n == 'Fruits'), hasLength(1));
    expect((await h.lists()).where((l) => l.name == 'Fruits'), hasLength(1));
  });

  test('queued_ops_survive_a_restart_and_inflight_is_reset_to_pending',
      () async {
    final h = SyncHarness();
    final a = await h.repo.createList('A');
    await h.repo.addItem(a, text: 'Pain');
    await h.repo.createList('B');
    final before = await h.ops();
    await h.db.outboxDao.setState(before.first.id, 'inFlight');

    final h2 = h.restart(); // new repository + coordinator, same database
    h2.api.failNext('listLists', const NetworkError());
    await h2.sync();

    final after = await h2.ops();
    expect(after.map((o) => o.id), before.map((o) => o.id)); // none lost
    expect(
        after.map((o) => o.opType), ['createList', 'createItem', 'createList']);
    expect(after.map((o) => o.state), everyElement('pending'));
    final first = jsonDecode(after.first.payloadJson) as Map<String, dynamic>;
    expect(first['adopt'], isTrue);
    expect(h2.api.count('createList'), 0);
    expect(await h2.items(), hasLength(1));
  });
}
