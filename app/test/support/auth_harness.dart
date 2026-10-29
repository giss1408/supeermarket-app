import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/auth_interceptor.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/auth/token_store.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/database_provider.dart';

import '../core/db/test_db.dart';
import 'fake_http.dart';
import 'in_memory_token_store.dart';

const baseUrl = 'https://api.test';

/// Real controller + interceptor + providers wired on fakes.
class AuthHarness {
  AuthHarness._(this.container, this.http, this.store, this.db);

  final ProviderContainer container;
  final FakeAdapter http;
  final InMemoryTokenStore store;
  final AppDatabase db;

  Dio get dio => container.read(dioProvider);
  SessionController get session => container.read(sessionProvider.notifier);
  Session get state => container.read(sessionProvider);
  AccessTokenHolder get tokens => container.read(accessTokenProvider);

  /// Scripts a successful `GET /me` for [id].
  void stubMe(int id, {String name = 'Client'}) => http.on(
        'GET',
        '/api/v1/me',
        (_, __) => FakeResponse(200, {
          'id': id,
          'email': 'u$id@example.ci',
          'name': name,
          'role': 'customer',
        }),
      );

  void stubLogin({String access = 'access-1', String refresh = 'refresh-1'}) =>
      http.reply('POST', '/auth/login', 200, {
        'access': access,
        'refresh': refresh,
      });

  /// Local data of user [tag]: list, outbox op, card (user-scoped) plus a
  /// flyer and payment methods (public).
  Future<void> seedData() async {
    await db.listsDao.upsertList(shoppingList('l1'));
    await db.listsDao.upsertItem(listItem('i1', 'l1'));
    await db.outboxDao.enqueue(op('createList'));
    await db.cardDao.setCard('123456', '123456');
    await db.syncMetaDao.set('lists_last_pull', 'x');
    await db.publicDao.replaceCurrentFlyer(flyer(1, current: true), [], []);
    await db.paymentDao.replaceMethods([
      const PaymentMethodRow(
        provider: 'wave',
        phoneNumber: '+225',
        displayName: 'Wave',
        instructions: 'x',
        updatedAt: '2026-10-29T20:10:13.725480Z',
      ),
    ]);
  }

  Future<Map<String, int>> counts() async => {
        'lists': (await db.listsDao.allLists()).length,
        'items': (await db.listsDao.itemsOf('l1')).length,
        'outbox': await db.outboxDao.pendingCount(),
        'card': (await db.cardDao.watchCard().first) == null ? 0 : 1,
        'flyers':
            (await db.publicDao.watchCurrentFlyer().first) == null ? 0 : 1,
        'payments': (await db.paymentDao.watchMethods().first).length,
      };
}

AuthHarness createAuthHarness({
  String? refresh,
  SessionUser? user,
  String? access,
  List<Override> overrides = const [],
}) {
  final db = createTestDb();
  final store = InMemoryTokenStore(refresh: refresh, user: user);
  final http = FakeAdapter();
  final container = ProviderContainer(overrides: [
    apiBaseUrlProvider.overrideWithValue(baseUrl),
    tokenStoreProvider.overrideWithValue(store),
    appDatabaseProvider.overrideWithValue(db),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  container.read(dioProvider).httpClientAdapter = http;
  container.read(bareDioProvider).httpClientAdapter = http;
  container.read(accessTokenProvider).value = access;
  return AuthHarness._(container, http, store, db);
}
