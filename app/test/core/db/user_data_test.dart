import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart' as keys;

import 'test_db.dart';

void main() {
  test('deleting a list cascades its items', () async {
    final db = createTestDb();
    final dao = db.listsDao;
    await dao.upsertList(shoppingList('a'));
    await dao.upsertList(shoppingList('b'));
    await dao.upsertItem(listItem('i1', 'a'));
    await dao.upsertItem(listItem('i2', 'b'));
    await dao.deleteList('a');
    expect(await dao.itemsOf('a'), isEmpty);
    expect((await dao.itemsOf('b')).length, 1);
    await dao.deleteItem('i2');
    expect(await dao.itemsOf('b'), isEmpty);
  });

  test('remoteId is unique on lists but NULLs may repeat', () async {
    final db = createTestDb();
    final dao = db.listsDao;
    await dao.upsertList(shoppingList('a'));
    await dao.upsertList(shoppingList('b'));
    await dao.upsertList(shoppingList('c', remoteId: 7));
    await expectLater(
        dao.upsertList(shoppingList('d', remoteId: 7)), throwsA(anything));
    expect((await dao.byRemoteId(7))?.localId, 'c');
    expect(await dao.byRemoteId(8), isNull);
    expect((await dao.allLists()).length, 3);
  });

  test('item CHECK constraints and item remoteId uniqueness per list',
      () async {
    final db = createTestDb();
    final dao = db.listsDao;
    await dao.upsertList(shoppingList('a'));
    await dao.upsertItem(listItem('ok1', 'a', quantity: 1));
    await dao.upsertItem(listItem('ok2', 'a', quantity: 999));
    await expectLater(
        dao.upsertItem(listItem('q0', 'a', quantity: 0)), throwsA(anything));
    await expectLater(dao.upsertItem(listItem('q1000', 'a', quantity: 1000)),
        throwsA(anything));
    await expectLater(
        dao.upsertItem(listItem('empty', 'a', text: '')), throwsA(anything));
    // A product-only item (no text) is fine.
    await db.publicDao.replaceCurrentFlyer(flyer(1), [product(1)], []);
    await dao.upsertItem(listItem('p', 'a', productId: 1, text: ''));
    expect((await dao.itemsOf('a')).length, 3);

    await dao
        .upsertItem(listItem('r1', 'a').copyWith(remoteId: const Value(5)));
    await expectLater(
        dao.upsertItem(listItem('r2', 'a').copyWith(remoteId: const Value(5))),
        throwsA(anything));
  });

  test('item for a missing list violates the foreign key', () async {
    final db = createTestDb();
    await expectLater(
        db.listsDao.upsertItem(listItem('x', 'nope')), throwsA(anything));
  });

  test('watchLists excludes deleted-locally, newest first; watchList orders',
      () async {
    final db = createTestDb();
    final dao = db.listsDao;
    await dao
        .upsertList(shoppingList('old', createdAt: '2026-10-01T00:00:00Z'));
    await dao
        .upsertList(shoppingList('new', createdAt: '2026-10-02T00:00:00Z'));
    await dao.upsertList(shoppingList('gone', createdAt: '2026-10-03T00:00:00Z')
        .copyWith(deletedLocally: true));
    expect(
        (await dao.watchLists().first).map((l) => l.localId), ['new', 'old']);

    await dao.upsertItem(listItem('i1', 'new', checked: true, createdAt: '1'));
    await dao.upsertItem(listItem('i2', 'new', createdAt: '3'));
    await dao.upsertItem(listItem('i3', 'new', createdAt: '2'));
    final detail = await dao.watchList('new').first;
    expect(detail?.list.localId, 'new');
    expect(detail?.items.map((i) => i.localId), ['i3', 'i2', 'i1']);
    final empty = await dao.watchList('old').first;
    expect(empty?.items, isEmpty);
    expect(await dao.watchList('missing').first, isNull);
  });

  test('watchList emits on item change', () async {
    final db = createTestDb();
    final dao = db.listsDao;
    await dao.upsertList(shoppingList('a'));
    final expectation = expectLater(
      dao.watchList('a').map((l) => l?.items.length),
      emitsInOrder([0, 1]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.upsertItem(listItem('i', 'a'));
    await expectation;
  });

  test('outbox: counts, setState attempts, reset, ordering', () async {
    final db = createTestDb();
    final dao = db.outboxDao;
    final a = await dao.enqueue(op('a'));
    final b = await dao.enqueue(op('b'));
    final c = await dao.enqueue(op('c'));
    expect(await dao.pendingCount(), 3);

    await dao.setState(b, 'inFlight');
    await dao.setState(c, 'failed', error: 'boom');
    expect(await dao.pendingCount(), 2);
    expect((await dao.pendingInOrder()).map((o) => o.id), [a, b]);

    var rows = await db.select(db.outboxOps).get();
    expect(rows.firstWhere((r) => r.id == b).attempts, 1);
    final failed = rows.firstWhere((r) => r.id == c);
    expect(failed.attempts, 1);
    expect(failed.lastError, 'boom');

    await dao.setState(b, 'failed', error: 'x');
    expect(
        (await db.select(db.outboxOps).get())
            .firstWhere((r) => r.id == b)
            .attempts,
        2);

    await dao.setState(a, 'inFlight');
    await dao.resetInFlightToPending();
    rows = await db.select(db.outboxOps).get();
    expect(rows.firstWhere((r) => r.id == a).state, 'pending');
    expect(rows.firstWhere((r) => r.id == b).state, 'failed');

    await dao.setState(a, 'pending');
    rows = await db.select(db.outboxOps).get();
    expect(rows.firstWhere((r) => r.id == a).attempts, 1);
    await dao.delete(a);
    expect(await dao.pendingCount(), 0);
  });

  test('outbox rejects an unknown state', () async {
    final db = createTestDb();
    final id = await db.outboxDao.enqueue(op('a'));
    await expectLater(db.outboxDao.setState(id, 'weird'), throwsA(anything));
  });

  test('watchPendingCount emits on change', () async {
    final db = createTestDb();
    final expectation = expectLater(
      db.outboxDao.watchPendingCount(),
      emitsInOrder([0, 1, 0]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final id = await db.outboxDao.enqueue(op('a'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.outboxDao.delete(id);
    await expectation;
  });

  test('card is a single row that is replaced', () async {
    final db = createTestDb();
    final expectation = expectLater(
      db.cardDao.watchCard().map((c) => c?.number),
      emitsInOrder([null, '1', '2']),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.cardDao.setCard('1', 'b1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.cardDao.setCard('2', 'b2');
    await expectation;
    expect((await db.select(db.loyaltyCard).get()).length, 1);
  });

  test('sync meta get/set/remove', () async {
    final db = createTestDb();
    final dao = db.syncMetaDao;
    expect(await dao.get('k'), isNull);
    await dao.set('k', 'v1');
    await dao.set('k', 'v2');
    expect(await dao.get('k'), 'v2');
    await dao.remove('k');
    expect(await dao.get('k'), isNull);
  });

  test('wipeUserData removes user data and keeps public data', () async {
    final db = createTestDb();
    await db.publicDao.upsertCategories([category(1, 'c')]);
    await db.publicDao.replaceCurrentFlyer(
        flyer(1), [product(1)], [offer(1, flyerId: 1, productId: 1)]);
    await db.storesDao.replaceStores([
      store(1)
    ], [
      const OpeningHoursRow(
          storeId: 1, weekday: 0, opens: '07:00', closes: '21:00')
    ]);
    await db.paymentDao.replaceMethods([
      const PaymentMethodRow(
        provider: 'wave',
        phoneNumber: '+225',
        displayName: 'Wave',
        instructions: 'x',
        updatedAt: '2026-10-29T20:10:13Z',
      ),
    ]);
    await db.listsDao.upsertList(shoppingList('a'));
    await db.listsDao.upsertItem(listItem('i', 'a'));
    await db.outboxDao.enqueue(op('a'));
    await db.cardDao.setCard('1', 'b');
    for (final k in [
      keys.listsLastPull,
      keys.lastUserId,
      keys.paymentLastChecked,
      keys.currentFlyerFetchedAt,
      keys.storesFetchedAt,
    ]) {
      await db.syncMetaDao.set(k, 'v');
    }

    await db.wipeUserData();

    expect(await db.select(db.shoppingLists).get(), isEmpty);
    expect(await db.select(db.listItems).get(), isEmpty);
    expect(await db.select(db.outboxOps).get(), isEmpty);
    expect(await db.select(db.loyaltyCard).get(), isEmpty);
    expect(await db.syncMetaDao.get(keys.listsLastPull), isNull);
    expect(await db.syncMetaDao.get(keys.lastUserId), isNull);

    expect((await db.select(db.flyers).get()).length, 1);
    expect((await db.select(db.offers).get()).length, 1);
    expect((await db.select(db.products).get()).length, 1);
    expect((await db.select(db.categories).get()).length, 1);
    expect((await db.select(db.stores).get()).length, 1);
    expect((await db.select(db.openingHours).get()).length, 1);
    expect((await db.select(db.paymentMethods).get()).length, 1);
    expect(await db.syncMetaDao.get(keys.paymentLastChecked), 'v');
    expect(await db.syncMetaDao.get(keys.currentFlyerFetchedAt), 'v');
    expect(await db.syncMetaDao.get(keys.storesFetchedAt), 'v');
  });
}
