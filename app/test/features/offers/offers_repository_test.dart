import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/sync/refresh_outcome.dart';
import 'package:supermarket_app/features/offers/data/offers_repository.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_http.dart';
import '../../support/offers_harness.dart';

Map<String, dynamic> currentFixture() =>
    Map<String, dynamic>.from(fixture('flyers_current') as Map);

void main() {
  test('cached_flyer_is_emitted_before_the_network_returns', () async {
    final h = Harness();
    await h.db.publicDao.replaceCurrentFlyer(
      flyer(9, current: true),
      [product(1)],
      [offer(1, flyerId: 9, productId: 1)],
    );
    final gate = Completer<void>();
    h.http.on('GET', '/flyers/current', (_, __) async {
      await gate.future;
      return FakeResponse(200, fixture('flyers_current'));
    });

    final pending = h.repo.refreshCurrentFlyer();
    final cached = await h.repo.watchCurrentFlyer().first;
    expect(cached?.id, 9);
    expect((await h.repo.watchOffers().first).single.offer.id, 1);

    gate.complete();
    expect(await pending, isA<Refreshed>());
    expect((await h.repo.watchCurrentFlyer().first)?.id, 1);
  });

  test('refresh_replaces_flyer_and_offers_atomically', () async {
    final h = Harness();
    await h.db.publicDao.replaceCurrentFlyer(
      flyer(9, current: true),
      [product(1)],
      [offer(100, flyerId: 9, productId: 1)],
    );
    final emissions = <List<int>>[];
    final sub = h.repo.watchOffers().listen(
          (l) => emissions.add(l.map((o) => o.offer.id).toList()..sort()),
        );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(emissions.first, [100]);
    // Never a mix of old and new offers, never an empty intermediate state.
    for (final e in emissions.skip(1)) {
      expect(e.contains(100), isFalse, reason: '$e');
      expect(e, isNotEmpty);
    }
    final ids = (await h.offerRows()).map((o) => o.id).toSet();
    expect(ids.contains(100), isFalse);
    expect(ids, isNotEmpty);
    final nine = await (h.db.select(h.db.flyers)..where((t) => t.id.equals(9)))
        .getSingle();
    expect(nine.isCurrent, isFalse);
  });

  test('a_failing_refresh_leaves_the_cache_untouched', () async {
    final h = Harness();
    await h.db.publicDao.replaceCurrentFlyer(
      flyer(9, current: true),
      [product(1)],
      [offer(100, flyerId: 9, productId: 1)],
    );
    await h.db.syncMetaDao.set(currentFlyerFetchedAt, 'old-value');

    Future<void> expectUntouched() async {
      expect((await h.repo.watchCurrentFlyer().first)?.id, 9);
      expect((await h.offerRows()).map((o) => o.id), [100]);
      expect(await h.db.syncMetaDao.get(currentFlyerFetchedAt), 'old-value');
    }

    // Network failure.
    h.http.on('GET', '/flyers/current', offline());
    var outcome = await h.repo.refreshCurrentFlyer(force: true);
    expect((outcome as Failed).error, isA<NetworkError>());
    await expectUntouched();

    // Server error.
    h.http.reply('GET', '/flyers/current', 500, errorBody('server_error'));
    outcome = await h.repo.refreshCurrentFlyer(force: true);
    expect((outcome as Failed).error, isA<ApiError>());
    await expectUntouched();

    // Payload that does not deserialize.
    final broken = currentFixture();
    (broken['offers'] as List<dynamic>)[0] = {'id': 1};
    h.http.reply('GET', '/flyers/current', 200, broken);
    outcome = await h.repo.refreshCurrentFlyer(force: true);
    expect(outcome, isA<Failed>());
    await expectUntouched();

    // Failure halfway through the write (duplicate offer id): rolled back.
    final dup = currentFixture();
    final offers =
        (dup['offers'] as List<dynamic>).cast<Map<String, dynamic>>();
    offers[1] = {...offers[1], 'id': offers[0]['id']};
    h.http.reply('GET', '/flyers/current', 200, dup);
    outcome = await h.repo.refreshCurrentFlyer(force: true);
    expect(outcome, isA<Failed>());
    await expectUntouched();

    // Failing categories request: nothing is written either.
    h.http.reply('GET', '/flyers/current', 200, fixture('flyers_current'));
    h.http.on('GET', '/categories', offline());
    outcome = await h.repo.refreshCurrentFlyer(force: true);
    expect(outcome, isA<Failed>());
    await expectUntouched();
  });

  test('refresh_within_ttl_is_skipped_unless_forced', () async {
    final h = Harness();
    expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
    expect(h.flyerCalls, 1);
    expect(
      await h.db.syncMetaDao.get(currentFlyerFetchedAt),
      DateTime.utc(2026, 10, 29, 8).toIso8601String(),
    );

    h.now = h.now.add(const Duration(minutes: 14, seconds: 59));
    expect(await h.repo.refreshCurrentFlyer(), isA<SkippedFresh>());
    expect(h.flyerCalls, 1);

    expect(await h.repo.refreshCurrentFlyer(force: true), isA<Refreshed>());
    expect(h.flyerCalls, 2);

    // A fetch time in the future or an unparsable one counts as stale.
    await h.db.syncMetaDao.set(
      currentFlyerFetchedAt,
      h.now.add(const Duration(minutes: 1)).toIso8601String(),
    );
    expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
    await h.db.syncMetaDao.set(currentFlyerFetchedAt, 'not a date');
    expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
    expect(h.flyerCalls, 4);
    await h.db.syncMetaDao.set(currentFlyerFetchedAt, h.now.toIso8601String());
    h.now = h.now.add(const Duration(minutes: 15));
    // 15 minutes after the last successful fetch it is stale again.
    h.now = h.now.add(const Duration(minutes: 15));
    expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
    expect(h.flyerCalls, 5);
  });

  for (final year in [2000, 2040]) {
    test(
        'the_current_flyer_is_the_one_the_server_returned_regardless_of_the_device_date ($year)',
        () async {
      final h = Harness(start: DateTime.utc(year, 6, 15));
      expect(await h.repo.refreshCurrentFlyer(), isA<Refreshed>());
      final f = await h.repo.watchCurrentFlyer().first;
      expect(f, isNotNull);
      expect(f!.id, 1);
      expect(f.isCurrent, isTrue);
      // Dates are stored as received, not interpreted.
      expect(f.validFrom, '2026-10-29');
      expect(f.validTo, '2026-11-04');
      expect((await h.repo.watchOffers().first), isNotEmpty);
    });
  }

  test('server_404_clears_the_current_flyer', () async {
    final h = Harness();
    await h.db.publicDao.replaceCurrentFlyer(
      flyer(9, current: true),
      [product(1)],
      [offer(100, flyerId: 9, productId: 1)],
    );
    h.http.reply('GET', '/flyers/current', 404, errorBody('not_found'));
    expect(await h.repo.refreshCurrentFlyer(force: true), isA<Refreshed>());
    expect(await h.repo.watchCurrentFlyer().first, isNull);
    expect(await h.repo.watchOffers().first, isEmpty);
    expect(await h.offerRows(), isEmpty);
    final old = await (h.db.select(h.db.flyers)..where((t) => t.id.equals(9)))
        .getSingle();
    expect(old.isCurrent, isFalse);
    // The next open re-checks instead of waiting for the TTL.
    expect(await h.db.syncMetaDao.get(currentFlyerFetchedAt), isNull);
  });

  test('categories_are_fetched_with_paging', () async {
    final h = Harness();
    h.http.on('GET', '/categories', (o, _) {
      if (o.uri.queryParameters['cursor'] == 'p2') {
        return FakeResponse(200, {
          'next': null,
          'previous': null,
          'results': [
            {'id': 20, 'name': 'Boissons', 'slug': 'boissons'},
          ],
        });
      }
      return FakeResponse(200, {
        'next': 'https://api.test/api/v1/categories/?cursor=p2',
        'previous': null,
        'results': [
          {'id': 10, 'name': 'Épicerie', 'slug': 'epicerie'},
        ],
      });
    });
    await h.repo.refreshCurrentFlyer();
    final cats = await h.repo.watchCategories().first;
    expect(cats.map((c) => c.slug), ['epicerie', 'boissons']);
    expect(h.http.callsTo('/categories'), hasLength(2));
  });

  group('mapping from the real fixtures', () {
    final detail = FlyerDetail.fromJson(
      Map<String, dynamic>.from(fixture('flyers_current') as Map),
    );

    test('offers keep price strings exactly, old price may be null', () {
      final rows = mapOffers(detail);
      expect(rows, hasLength(detail.offers.length));
      expect(rows[0].price, '750.00');
      expect(rows[0].oldPrice, '1000.00');
      expect(rows[0].badgeText, '-25%');
      expect(rows[0].flyerId, 1);
      expect(rows[1].price, '1000.00');
      expect(rows[1].oldPrice, isNull);
      expect(rows[1].badgeText, '');
      expect(rows[0].sortOrder, 0);
      expect(rows[1].sortOrder, 1);
      expect(rows[0].validFrom, isNull);
    });

    test('products keep null image and category ids', () {
      final rows = mapProducts(detail);
      expect(rows.map((p) => p.id).toSet().length, rows.length);
      final bananas = rows.firstWhere((p) => p.id == 1);
      expect(bananas.name, 'Bananes plantain');
      expect(bananas.imageUrl, isNull);
      expect(bananas.categoryId, 1);
      expect(bananas.unit, '1 kg');
      expect(bananas.description, '');
    });
  });
}
