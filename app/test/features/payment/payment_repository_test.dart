import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/features/payment/data/payment_repository.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_http.dart';
import '../../support/offers_harness.dart' show fixture;

class H {
  H() {
    db = createTestDb();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = http;
    repo = PaymentRepository(dio: dio, db: db, clock: () => now);
    http.reply('GET', '/payment-methods', 200, fixture('payment_methods'));
  }

  late final AppDatabase db;
  late final PaymentRepository repo;
  final http = FakeAdapter();
  DateTime now = DateTime.utc(2026, 10, 30, 14, 32);

  Future<List<String>> providers() async =>
      (await repo.watchMethods().first).map((m) => m.provider).toList();
}

Map<String, dynamic> withoutProvider(String p) {
  final f = Map<String, dynamic>.from(fixture('payment_methods') as Map);
  f['results'] = [
    for (final r in f['results'] as List)
      if ((r as Map)['provider'] != p) r,
  ];
  return f;
}

void main() {
  test('refresh_stores_fixture_methods_and_last_checked', () async {
    final h = H();
    final result = await h.repo.refresh();
    expect(result, isA<Refreshed>());
    expect(await h.providers(), ['mtn_momo', 'orange_money', 'wave']);
    final wave = (await h.repo.watchMethods().first).last;
    expect(wave.phoneNumber, '+2250100000001');
    expect(wave.updatedAt, '2026-10-29T20:10:13.693225Z');
    expect(await h.repo.watchLastChecked().first, h.now);
  });

  test('a_provider_missing_from_the_new_list_is_deleted', () async {
    final h = H();
    await h.repo.refresh();
    h.http.reply('GET', '/payment-methods', 200, withoutProvider('wave'));
    await h.repo.refresh();
    expect(await h.providers(), ['mtn_momo', 'orange_money']);
  });

  test('an_unknown_provider_is_skipped_and_the_rest_stored', () async {
    final h = H();
    final body = Map<String, dynamic>.from(fixture('payment_methods') as Map);
    (body['results'] as List).add({
      'provider': 'moov_money',
      'phone_number': '+2250900000009',
      'display_name': 'Moov',
      'instructions': '',
      'updated_at': '2026-10-29T20:10:13Z',
    });
    h.http.reply('GET', '/payment-methods', 200, body);
    expect(await h.repo.refresh(), isA<Refreshed>());
    expect(await h.providers(), ['mtn_momo', 'orange_money', 'wave']);
  });

  test('a_failing_refresh_keeps_cache_and_previous_last_checked', () async {
    final h = H();
    await h.repo.refresh();
    final before = h.now;
    h.now = DateTime.utc(2026, 10, 31, 9);
    h.http.on('GET', '/payment-methods', offline());
    final result = await h.repo.refresh();
    expect(result, isA<Failed>());
    expect((result as Failed).error, isA<NetworkError>());
    expect(await h.providers(), ['mtn_momo', 'orange_money', 'wave']);
    expect(await h.repo.watchLastChecked().first, before);
    expect(await h.db.syncMetaDao.get(paymentLastChecked), isNotNull);
  });

  test('concurrent_refreshes_make_one_request', () async {
    final h = H();
    final gate = Completer<void>();
    h.http.on('GET', '/payment-methods', (_, __) async {
      await gate.future;
      return FakeResponse(200, fixture('payment_methods'));
    });
    final a = h.repo.refresh();
    final b = h.repo.refresh();
    gate.complete();
    await Future.wait([a, b]);
    expect(h.http.callsTo('/payment-methods'), hasLength(1));
    // No TTL: a later call fetches again.
    await h.repo.refresh();
    expect(h.http.callsTo('/payment-methods'), hasLength(2));
  });
}
