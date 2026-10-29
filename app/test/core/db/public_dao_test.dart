import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'test_db.dart';

void main() {
  test('replaceCurrentFlyer replaces offers and demotes the previous flyer',
      () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao.replaceCurrentFlyer(
      flyer(1),
      [product(1), product(2)],
      [offer(1, flyerId: 1, productId: 1), offer(2, flyerId: 1, productId: 2)],
    );
    await dao.replaceCurrentFlyer(
      flyer(2),
      [product(2), product(3)],
      [offer(3, flyerId: 2, productId: 3)],
    );

    final current = await dao.watchCurrentFlyer().first;
    expect(current?.id, 2);
    expect(current?.isCurrent, isTrue);
    final old =
        await (db.select(db.flyers)..where((t) => t.id.equals(1))).getSingle();
    expect(old.isCurrent, isFalse);
    final offers = await db.select(db.offers).get();
    expect(offers.map((o) => o.id), [3]);
    // Products are shared and kept.
    expect((await db.select(db.products).get()).length, 3);
  });

  test('replaceCurrentFlyer re-run for the same flyer replaces its offers',
      () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao.replaceCurrentFlyer(
        flyer(1), [product(1)], [offer(1, flyerId: 1, productId: 1)]);
    await dao.replaceCurrentFlyer(
        flyer(1), [product(1)], [offer(2, flyerId: 1, productId: 1)]);
    expect((await db.select(db.offers).get()).map((o) => o.id), [2]);
  });

  test('a failing step (unknown product, FK enforced) changes nothing',
      () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao.replaceCurrentFlyer(
        flyer(1), [product(1)], [offer(1, flyerId: 1, productId: 1)]);

    await expectLater(
      dao.replaceCurrentFlyer(
        flyer(2),
        [product(5)],
        [
          offer(10, flyerId: 2, productId: 5),
          offer(11, flyerId: 2, productId: 999),
        ],
      ),
      throwsA(anything),
    );

    expect((await dao.watchCurrentFlyer().first)?.id, 1);
    expect((await db.select(db.offers).get()).map((o) => o.id), [1]);
    expect(await (db.select(db.flyers)..where((t) => t.id.equals(2))).get(),
        isEmpty);
    expect(await (db.select(db.products)..where((t) => t.id.equals(5))).get(),
        isEmpty);
  });

  test('a duplicate offer id also rolls back', () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao.replaceCurrentFlyer(
        flyer(1), [product(1)], [offer(1, flyerId: 1, productId: 1)]);
    await expectLater(
      dao.replaceCurrentFlyer(flyer(2), [
        product(1)
      ], [
        offer(7, flyerId: 2, productId: 1),
        offer(7, flyerId: 2, productId: 1),
      ]),
      throwsA(anything),
    );
    expect((await dao.watchCurrentFlyer().first)?.id, 1);
    expect((await db.select(db.offers).get()).map((o) => o.id), [1]);
  });

  test('watchCurrentOffers filters, searches literally and orders', () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao
        .upsertCategories([category(1, 'fruits'), category(2, 'boissons')]);
    await dao.replaceCurrentFlyer(
      flyer(1),
      [
        product(1, name: 'Banane', categoryId: 1),
        product(2, name: 'Jus 100% pur', categoryId: 2),
        product(3, name: 'Jus_orange', categoryId: 2),
        product(4, name: 'Sans categorie'),
      ],
      [
        offer(1, flyerId: 1, productId: 1, sortOrder: 3),
        offer(2, flyerId: 1, productId: 2, sortOrder: 1),
        offer(3, flyerId: 1, productId: 3, sortOrder: 1, badge: '-25%'),
        offer(4, flyerId: 1, productId: 4, sortOrder: 2),
      ],
    );

    var all = await dao.watchCurrentOffers().first;
    expect(all.map((o) => o.offer.id), [2, 3, 4, 1]);
    expect(all.last.category?.slug, 'fruits');
    expect(all[2].category, isNull);

    final fruits = await dao.watchCurrentOffers(categorySlug: 'fruits').first;
    expect(fruits.map((o) => o.offer.id), [1]);

    final ban = await dao.watchCurrentOffers(query: 'BANAN').first;
    expect(ban.map((o) => o.offer.id), [1]);

    final pct = await dao.watchCurrentOffers(query: '%').first;
    expect(pct.map((o) => o.offer.id), [2, 3]); // product 2 name, offer 3 badge
    final under = await dao.watchCurrentOffers(query: '_').first;
    expect(under.map((o) => o.offer.id), [3]);
    final both = await dao
        .watchCurrentOffers(categorySlug: 'boissons', query: 'orange')
        .first;
    expect(both.map((o) => o.offer.id), [3]);
  });

  test('upsertArchiveFlyers keeps the current flag; archive ordering',
      () async {
    final db = createTestDb();
    final dao = db.publicDao;
    await dao.replaceCurrentFlyer(flyer(1), [], []);
    await dao.upsertArchiveFlyers([
      flyer(1, validFrom: '2026-10-29'),
      flyer(2, validFrom: '2026-10-01'),
      flyer(3, validFrom: '2026-10-15'),
    ]);
    expect((await dao.watchCurrentFlyer().first)?.id, 1);
    expect((await dao.watchArchive().first).map((f) => f.id), [3, 2]);
  });

  test('watchCategories orders by sortOrder then name and emits updates',
      () async {
    final db = createTestDb();
    final dao = db.publicDao;
    final stream = dao.watchCategories();
    final expectation = expectLater(
      stream.map((l) => l.map((c) => c.slug).toList()),
      emitsInOrder([
        <String>[],
        ['b'],
        ['b', 'a'],
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.upsertCategories([category(1, 'b', sortOrder: 1)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await dao.upsertCategories([category(2, 'a', sortOrder: 2)]);
    await expectation;
  });

  test('watchCurrentFlyer emits null then the flyer', () async {
    final db = createTestDb();
    final expectation = expectLater(
      db.publicDao.watchCurrentFlyer().map((f) => f?.id),
      emitsInOrder([null, 4]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.publicDao.replaceCurrentFlyer(flyer(4), [], []);
    await expectation;
    // keep analyzer happy about unused import
    expect(const Value(1).value, 1);
  });
}
