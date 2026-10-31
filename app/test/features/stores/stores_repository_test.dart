import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/sync/refresh_outcome.dart';
import 'package:supermarket_app/features/stores/data/stores_repository.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_http.dart';
import '../../support/offers_harness.dart' show fixture;

class StoresRepoHarness {
  StoresRepoHarness() {
    db = createTestDb();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = http;
    repo = StoresRepository(
      storesApi: ApiClient(dio: dio, interceptors: const []).getStoresApi(),
      db: db,
      clock: () => now,
    );
    http.reply('GET', '/stores', 200, fixture('stores_list'));
    for (final id in [1, 2, 3, 4, 5]) {
      http.on('GET', '/stores/$id', (_, __) {
        final d = Map<String, dynamic>.from(fixture('store_detail') as Map);
        d['id'] = id;
        return FakeResponse(200, d);
      });
    }
  }

  late final AppDatabase db;
  late final StoresRepository repo;
  final http = FakeAdapter();
  DateTime now = DateTime.utc(2026, 10, 29, 8);
}

void main() {
  test('refresh stores the list and the hours from the details', () async {
    final h = StoresRepoHarness();
    h.http.reply('GET', '/stores/3', 500, errorBody('server_error'));

    final outcome = await h.repo.refresh();

    expect(outcome, isA<Refreshed>());
    final stores = await h.db.select(h.db.stores).get();
    expect(stores, hasLength(5));
    final hours = await h.db.select(h.db.openingHours).get();
    expect(hours.where((r) => r.storeId == 5), hasLength(6));
    expect(hours.where((r) => r.storeId == 3), isEmpty);
    expect(await h.db.syncMetaDao.get(storesFetchedAt), isNotNull);
  });

  test('a failing list fetch leaves the cache untouched', () async {
    final h = StoresRepoHarness();
    await h.db.storesDao.replaceStores([store(9)], const []);
    h.http.on('GET', '/stores', offline());

    final outcome = await h.repo.refresh();

    expect(outcome, isA<Failed>());
    expect((outcome as Failed).error, isA<NetworkError>());
    final stores = await h.db.select(h.db.stores).get();
    expect(stores.map((s) => s.id), [9]);
    expect(await h.db.syncMetaDao.get(storesFetchedAt), isNull);
  });

  test('refresh within the TTL is skipped unless forced', () async {
    final h = StoresRepoHarness();
    await h.repo.refresh();
    final calls = h.http.callsTo('/stores').length;

    h.now = h.now.add(const Duration(hours: 23));
    expect(await h.repo.refresh(), isA<SkippedFresh>());
    expect(h.http.callsTo('/stores').length, calls);

    expect(await h.repo.refresh(force: true), isA<Refreshed>());
    expect(h.http.callsTo('/stores').length, greaterThan(calls));

    h.now = h.now.add(const Duration(hours: 25));
    expect(await h.repo.refresh(), isA<Refreshed>());
  });

  test('refreshStore replaces the hours of one store', () async {
    final h = StoresRepoHarness();
    await h.db.storesDao.replaceStores([store(5)], const []);
    await h.repo.refreshStore(5);
    final hours = await h.db.select(h.db.openingHours).get();
    expect(hours, hasLength(6));
  });

  test('a failed detail keeps cached hours; dropped stores are removed',
      () async {
    final h = StoresRepoHarness();
    await h.repo.refresh();
    // Store 4 gets new hours, store 3 keeps its old ones, store 2 vanishes.
    h.http.on('GET', '/stores/4', (_, __) {
      final d = Map<String, dynamic>.from(fixture('store_detail') as Map);
      d['id'] = 4;
      d['opening_hours'] = [
        {'weekday': 0, 'opens': '09:00', 'closes': '12:00'},
      ];
      return FakeResponse(200, d);
    });
    h.http.reply('GET', '/stores/3', 500, errorBody('server_error'));
    final list = Map<String, dynamic>.from(fixture('stores_list') as Map);
    list['results'] = [
      for (final s in list['results'] as List)
        if ((s as Map)['id'] != 2) s,
    ];
    h.http.reply('GET', '/stores', 200, list);

    expect(await h.repo.refresh(force: true), isA<Refreshed>());

    final hours = await h.db.select(h.db.openingHours).get();
    expect(hours.where((r) => r.storeId == 3), hasLength(6));
    expect(hours.where((r) => r.storeId == 4).map((r) => r.opens), ['09:00']);
    expect(hours.where((r) => r.storeId == 2), isEmpty);
    final ids = (await h.db.select(h.db.stores).get()).map((s) => s.id);
    expect(ids, isNot(contains(2)));
    expect(ids, hasLength(4));
  });
}
