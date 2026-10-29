import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/search_functions.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDb();
    await db.publicDao.upsertCategories([category(1, 'c')]);
    await db.publicDao.replaceCurrentFlyer(
      flyer(1),
      [
        product(1, name: 'Café').copyWith(name: 'Café'),
        product(2).copyWith(name: 'Épices'),
        product(3).copyWith(name: 'Éclairs'),
        product(4).copyWith(name: 'Lait'),
      ],
      [
        offer(1, flyerId: 1, productId: 1),
        offer(2, flyerId: 1, productId: 2),
        offer(3, flyerId: 1, productId: 3),
        offer(4, flyerId: 1, productId: 4, badge: 'Prix choc : 2 pour 1'),
      ],
    );
    await db.storesDao.replaceStores([
      store(1).copyWith(name: 'Bouaké Centre', city: 'Bouaké'),
      store(2).copyWith(name: 'Yopougon', city: 'Abidjan'),
    ], []);
  });

  Future<List<int>> offersFor(String q) async =>
      (await db.publicDao.watchCurrentOffers(query: q).first)
          .map((o) => o.offer.id)
          .toList();
  Future<List<int>> storesFor(String q) async =>
      (await db.storesDao.watchStores(query: q).first)
          .map((s) => s.id)
          .toList();

  test('offers: accent and case insensitive', () async {
    for (final q in ['cafe', 'CAFÉ', 'café']) {
      expect(await offersFor(q), [1], reason: q);
    }
    expect(await offersFor('epices'), [2]);
    expect(await offersFor('épices'), [2]);
    expect(await offersFor('eclair'), [3]);
    expect(await offersFor('prix choc'), [4]);
  });

  test('offers: literal wildcards and blank queries', () async {
    expect(await offersFor('%'), isEmpty);
    expect(await offersFor('_'), isEmpty);
    expect((await offersFor('  ')).length, 4);
    expect((await offersFor('́')).length, 4);
  });

  test('stores: accent and case insensitive', () async {
    expect(await storesFor('bouake'), [1]);
    expect(await storesFor('BOUAKÉ'), [1]);
    expect(await storesFor('yopougon'), [2]);
    expect(await storesFor('%'), isEmpty);
  });

  test('registerSearchFunctions is usable via NativeDatabase setup', () async {
    final raw =
        AppDatabase(NativeDatabase.memory(setup: registerSearchFunctions));
    addTearDown(raw.close);
    final row = await raw
        .customSelect("SELECT fold_search('Éclair') AS v, "
            'fold_search(NULL) AS n, fold_search(12) AS i')
        .getSingle();
    expect(row.read<String>('v'), 'eclair');
    expect(row.read<String?>('n'), isNull);
    expect(row.read<String>('i'), '12');
  });
}
