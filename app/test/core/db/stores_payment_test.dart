import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';

import 'test_db.dart';

PaymentMethodRow pm(String provider) => PaymentMethodRow(
      provider: provider,
      phoneNumber: '+225',
      displayName: provider,
      instructions: 'x',
      updatedAt: '2026-10-29T20:10:13.725480Z',
    );

OpeningHoursRow hours(int storeId, int weekday) => OpeningHoursRow(
      storeId: storeId,
      weekday: weekday,
      opens: '07:00',
      closes: '21:00',
    );

void main() {
  test('upsertStoreWithHours replaces only that store hours; watchAllHours',
      () async {
    final db = createTestDb();
    await db.storesDao.replaceStores(
        [store(1), store(2)], [hours(1, 0), hours(1, 1), hours(2, 0)]);
    await db.storesDao.upsertStoreWithHours(store(1, city: 'Bouaké'), [
      hours(1, 3),
    ]);
    final all = await db.storesDao.watchAllHours().first;
    expect(all.map((h) => (h.storeId, h.weekday)).toSet(), {(1, 3), (2, 0)});
    final s = await db.storesDao.watchStore(1).first;
    expect(s!.store.city, 'Bouaké');
  });

  test('deleting a store cascades its opening hours', () async {
    final db = createTestDb();
    await db.storesDao.replaceStores(
        [store(1), store(2)], [hours(1, 0), hours(1, 1), hours(2, 0)]);
    await (db.delete(db.stores)..where((t) => t.id.equals(1))).go();
    final left = await db.select(db.openingHours).get();
    expect(left.map((h) => h.storeId), [2]);
  });

  test('opening hours primary key is (storeId, weekday)', () async {
    final db = createTestDb();
    await expectLater(
      db.storesDao.replaceStores([store(1)], [hours(1, 0), hours(1, 0)]),
      throwsA(anything),
    );
    expect(await db.select(db.stores).get(), isEmpty);
  });

  test('replaceStores fully replaces and watchStores searches by name',
      () async {
    final db = createTestDb();
    final dao = db.storesDao;
    await dao.replaceStores(
      [store(1, name: 'Zeta'), store(2, name: 'Alpha', city: 'Bouaké')],
      [],
    );
    expect((await dao.watchStores().first).map((s) => s.id), [2, 1]);
    expect((await dao.watchStores(query: 'bouak').first).map((s) => s.id), [2]);
    expect((await dao.watchStores(query: 'rue 1').first).map((s) => s.id), [1]);
    expect((await dao.watchStores(query: '%').first), isEmpty);
    await dao.replaceStores([store(3)], []);
    expect((await dao.watchStores().first).map((s) => s.id), [3]);
  });

  test('watchStore returns hours ordered by weekday', () async {
    final db = createTestDb();
    await db.storesDao
        .replaceStores([store(1)], [hours(1, 3), hours(1, 0), hours(1, 5)]);
    final s = await db.storesDao.watchStore(1).first;
    expect(s?.store.id, 1);
    expect(s?.hours.map((h) => h.weekday), [0, 3, 5]);
    expect(await db.storesDao.watchStore(99).first, isNull);
  });

  test('replaceMethods deletes methods missing from the new list', () async {
    final db = createTestDb();
    final dao = db.paymentDao;
    await dao.replaceMethods([pm('wave'), pm('orange_money'), pm('mtn_momo')]);
    expect((await dao.watchMethods().first).map((m) => m.provider),
        ['mtn_momo', 'orange_money', 'wave']);
    await dao.replaceMethods([pm('wave')]);
    expect((await dao.watchMethods().first).map((m) => m.provider), ['wave']);
    await dao.replaceMethods([]);
    expect(await dao.watchMethods().first, isEmpty);
  });
}
