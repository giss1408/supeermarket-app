import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/auth/token_store.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart' as keys;
import 'package:supermarket_app/core/errors/app_error.dart';

import '../../core/db/test_db.dart';
import '../../support/auth_harness.dart';
import '../../support/fake_http.dart';
import '../../support/in_memory_token_store.dart';

const _userA = SessionUser(id: '1', email: 'u1@example.ci', name: 'A');

Future<AppError> errorOf(Future<void> f) async {
  try {
    await f;
  } on AppError catch (e) {
    return e;
  }
  fail('expected an AppError');
}

void main() {
  group('restore', () {
    test(
        'restore_with_token_and_stored_user_is_signed_in_offline_without_any_request',
        () async {
      final h = createAuthHarness(refresh: 'r0', user: _userA);
      await h.session.restore();
      expect(h.state, isA<SignedIn>());
      expect((h.state as SignedIn).user, _userA);
      expect(h.http.calls, isEmpty);
      expect(h.tokens.value, isNull, reason: 'interceptor refreshes lazily');
    });

    test('restore_without_token_is_guest', () async {
      final h = createAuthHarness();
      await h.session.restore();
      expect(h.state, isA<Guest>());
      expect(h.http.calls, isEmpty);
    });

    test('restore_with_token_but_no_user_signs_in_online', () async {
      final h = createAuthHarness(refresh: 'r0');
      h.http.reply(
          'POST', '/auth/refresh', 200, {'access': 'a1', 'refresh': 'r1'});
      h.stubMe(2);
      await h.session.restore();
      expect((h.state as SignedIn).user.id, '2');
      expect(h.store.refresh, 'r1');
      expect(h.store.user?.id, '2');
      expect(h.tokens.value, 'a1');
    });

    test(
        'restore_with_token_but_no_user_clears_store_when_online_restore_fails',
        () async {
      final h = createAuthHarness(refresh: 'r0');
      h.http.on('POST', '/auth/refresh', offline());
      await h.session.restore();
      expect(h.state, isA<Guest>());
      expect(h.store.refresh, isNull);
      expect(h.store.user, isNull);
    });

    test('restore_never_throws_even_if_the_store_does', () async {
      final h = createAuthHarness(overrides: [
        tokenStoreProvider.overrideWithValue(_ThrowingStore()),
      ]);
      await h.session.restore();
      expect(h.state, isA<Guest>());
    });
  });

  group('signIn', () {
    test('sign_in_trims_email_stores_refresh_and_user_not_access_token',
        () async {
      final h = createAuthHarness();
      h.stubLogin(access: 'ACCESS-SECRET', refresh: 'REFRESH-1');
      h.stubMe(2, name: 'Awa');
      await h.session.signIn('  Awa@Example.ci \n', 'hunter2hunter2');

      final login = h.http.callsTo('/auth/login').single;
      expect(jsonDecode(login.body!), {
        'email': 'Awa@Example.ci',
        'password': 'hunter2hunter2',
      });
      expect(login.authorization, isNull);
      expect(h.state, isA<SignedIn>());
      expect((h.state as SignedIn).user.name, 'Awa');
      // Persisted: refresh token and user only.
      expect(h.store.refresh, 'REFRESH-1');
      expect(h.store.user,
          const SessionUser(id: '2', email: 'u2@example.ci', name: 'Awa'));
      expect(h.store.log.join(), isNot(contains('ACCESS-SECRET')));
      expect(h.store.log.join(), isNot(contains('hunter2')));
      // Access token only in memory.
      expect(h.tokens.value, 'ACCESS-SECRET');
      expect(h.http.callsTo('/api/v1/me').single.authorization,
          'Bearer ACCESS-SECRET');
      expect(await h.db.syncMetaDao.get(keys.lastUserId), '2');
    });

    test('sign_in_wrong_password_401_throws_api_error_and_changes_nothing',
        () async {
      final h = createAuthHarness();
      h.http.reply('POST', '/auth/login', 401, errorBody('not_authenticated'));
      final e = await errorOf(h.session.signIn('a@b.ci', 'bad'));
      expect(e, isA<ApiError>());
      expect((e as ApiError).status, 401);
      expect(h.state, isA<Guest>());
      expect(h.store.log, isEmpty);
      expect(h.tokens.value, isNull);
      expect(h.http.callsTo('/auth/refresh'), isEmpty,
          reason: 'no refresh logic');
      expect(await h.db.syncMetaDao.get(keys.lastUserId), isNull);
    });

    test('sign_in_throttled_429_maps_to_throttled', () async {
      final h = createAuthHarness();
      h.http.reply('POST', '/auth/login', 429, errorBody('throttled'));
      final e = await errorOf(h.session.signIn('a@b.ci', 'x'));
      expect((e as ApiError).code, 'throttled');
      expect(e.status, 429);
    });

    test('sign_in_offline_throws_network_error_and_changes_nothing', () async {
      final h = createAuthHarness();
      h.http.on('POST', '/auth/login', offline());
      expect(
          await errorOf(h.session.signIn('a@b.ci', 'x')), isA<NetworkError>());
      expect(h.state, isA<Guest>());
      expect(h.store.log, isEmpty);
    });

    test('sign_in_me_failure_leaves_everything_unchanged', () async {
      final h = createAuthHarness();
      h.stubLogin();
      h.http.reply('GET', '/api/v1/me', 500, errorBody('server_error'));
      await errorOf(h.session.signIn('a@b.ci', 'x'));
      expect(h.state, isA<Guest>());
      expect(h.store.log, isEmpty);
      expect(h.tokens.value, isNull);
    });

    test('signing_in_as_a_different_user_wipes_previous_users_data_first',
        () async {
      final h = createAuthHarness();
      h.stubLogin();
      h.stubMe(1);
      await h.session.signIn('u1@example.ci', 'pw');
      await h.seedData();
      expect((await h.counts())['lists'], 1);
      expect(await h.db.syncMetaDao.get(keys.lastUserId), '1');

      // B signs in without any sign-out in between.
      h.stubMe(2);
      // Observe the data at the moment B's /me answers: A's data must be
      // gone before the new session is exposed.
      SessionUser? exposedWith;
      var listsWhenExposed = -1;
      h.container.listen(sessionProvider, (_, next) async {
        if (next is SignedIn) {
          exposedWith = next.user;
          listsWhenExposed = (await h.db.listsDao.allLists()).length;
        }
      });
      await h.session.signIn('u2@example.ci', 'pw');
      await Future<void>.delayed(Duration.zero);

      expect((h.state as SignedIn).user.id, '2');
      expect(exposedWith?.id, '2');
      expect(listsWhenExposed, 0);
      expect(await h.counts(), {
        'lists': 0,
        'items': 0,
        'outbox': 0,
        'card': 0,
        'flyers': 1,
        'payments': 1,
      });
      expect(await h.db.syncMetaDao.get(keys.lastUserId), '2');
      expect(await h.db.syncMetaDao.get('lists_last_pull'), isNull);
    });

    test('same_user_sign_in_keeps_data', () async {
      final h = createAuthHarness();
      h.stubLogin();
      h.stubMe(1);
      await h.session.signIn('u1@example.ci', 'pw');
      await h.seedData();
      await h.session.signOut(discardUnsynced: true);
      // sign-out wipes; sign in again, seed, and re-sign-in as the same user
      await h.session.signIn('u1@example.ci', 'pw');
      await h.seedData();
      await h.session.signIn('u1@example.ci', 'pw');
      expect(await h.counts(), {
        'lists': 1,
        'items': 1,
        'outbox': 1,
        'card': 1,
        'flyers': 1,
        'payments': 1,
      });
    });

    test('storage_failure_on_sign_in_rolls_back_and_throws_unknown', () async {
      final store = _FailingUserWriteStore();
      final h = createAuthHarness(overrides: [
        tokenStoreProvider.overrideWithValue(store),
      ]);
      h.stubLogin();
      h.stubMe(1);
      expect(
          await errorOf(h.session.signIn('a@b.ci', 'x')), isA<UnknownError>());
      expect(h.state, isA<Guest>());
      expect(store.refresh, isNull);
      expect(h.tokens.value, isNull);
    });
  });

  group('register', () {
    test('register_signs_in_after_success', () async {
      final h = createAuthHarness();
      h.http.reply('POST', '/auth/register', 201, {
        'id': 5,
        'email': 'new@example.ci',
        'name': 'Nina',
        'role': 'customer'
      });
      h.stubLogin(access: 'a9', refresh: 'r9');
      h.stubMe(5, name: 'Nina');
      await h.session.register(
          email: ' new@example.ci ', password: 'pw-pw-pw-1', name: ' Nina ');
      final reg = jsonDecode(h.http.callsTo('/auth/register').single.body!);
      expect(reg, {
        'email': 'new@example.ci',
        'password': 'pw-pw-pw-1',
        'name': 'Nina',
      });
      expect(h.http.callsTo('/auth/login'), hasLength(1));
      expect((h.state as SignedIn).user.id, '5');
      expect(h.store.refresh, 'r9');
    });

    test('register_2xx_with_unparseable_body_still_signs_in', () async {
      final h = createAuthHarness();
      h.http.reply('POST', '/auth/register', 201, {'unexpected': true});
      h.stubLogin();
      h.stubMe(5);
      await h.session.register(email: 'a@b.ci', password: 'pw', name: 'N');
      expect(h.state, isA<SignedIn>());
    });

    test('register_400_exposes_field_errors_and_does_not_sign_in', () async {
      final h = createAuthHarness();
      h.http.reply('POST', '/auth/register', 400, {
        'code': 'validation_error',
        'detail': 'Invalid input.',
        'fields': {
          'password': ['Ce mot de passe est trop court.'],
          'email': ['Cette adresse est déjà utilisée.'],
        },
      });
      final e = await errorOf(
          h.session.register(email: 'a@b.ci', password: 'x', name: 'N'));
      expect(e, isA<ApiError>());
      expect((e as ApiError).fields.keys, containsAll(['password', 'email']));
      expect(h.http.callsTo('/auth/login'), isEmpty);
      expect(h.state, isA<Guest>());
      expect(h.store.log, isEmpty);
    });
  });

  group('signOut', () {
    Future<AuthHarness> signedInWithData() async {
      final h = createAuthHarness();
      h.stubLogin(access: 'a1', refresh: 'r1');
      h.stubMe(1);
      await h.session.signIn('u1@example.ci', 'pw');
      return h;
    }

    test('sign_out_online_calls_logout_then_wipes', () async {
      final h = await signedInWithData();
      await h.db.listsDao.upsertList(shoppingList('l1'));
      await h.db.cardDao.setCard('1', '1');
      await h.db.publicDao.replaceCurrentFlyer(flyer(1, current: true), [], []);
      h.http.reply('POST', '/auth/logout', 204);
      final r = await h.session.signOut(discardUnsynced: false);
      expect(r, isA<SignedOut>());
      final logout = h.http.callsTo('/auth/logout').single;
      expect(jsonDecode(logout.body!), {'refresh': 'r1'});
      expect(h.state, isA<Guest>());
      expect(h.store.refresh, isNull);
      expect(h.store.user, isNull);
      expect(h.tokens.value, isNull);
      expect((await h.db.listsDao.allLists()), isEmpty);
      expect(await h.db.cardDao.watchCard().first, isNull);
      expect(await h.db.syncMetaDao.get(keys.lastUserId), isNull);
      expect(await h.db.publicDao.watchCurrentFlyer().first, isNotNull);
    });

    test('sign_out_offline_still_wipes_and_signs_out', () async {
      final h = await signedInWithData();
      await h.db.listsDao.upsertList(shoppingList('l1'));
      h.http.on('POST', '/auth/logout', offline());
      final r = await h.session.signOut(discardUnsynced: false);
      expect(r, isA<SignedOut>());
      expect(h.state, isA<Guest>());
      expect(h.store.refresh, isNull);
      expect(await h.db.listsDao.allLists(), isEmpty);
    });

    test('sign_out_server_error_still_signs_out', () async {
      final h = await signedInWithData();
      h.http.reply('POST', '/auth/logout', 500, errorBody('server_error'));
      expect(await h.session.signOut(discardUnsynced: false), isA<SignedOut>());
      expect(h.state, isA<Guest>());
    });

    test(
        'sign_out_with_pending_outbox_and_no_discard_returns_blocked_with_count_and_changes_nothing',
        () async {
      final h = await signedInWithData();
      await h.db.listsDao.upsertList(shoppingList('l1'));
      await h.db.outboxDao.enqueue(op('createList'));
      await h.db.outboxDao.enqueue(op('renameList'));
      h.http.calls.clear();
      expect(await h.session.unsyncedCount(), 2);
      final r = await h.session.signOut(discardUnsynced: false);
      expect(r, isA<BlockedByUnsynced>());
      expect((r as BlockedByUnsynced).count, 2);
      expect(h.state, isA<SignedIn>());
      expect(h.store.refresh, 'r1');
      expect(h.tokens.value, 'a1');
      expect(await h.db.outboxDao.pendingCount(), 2);
      expect(await h.db.listsDao.allLists(), hasLength(1));
      expect(h.http.calls, isEmpty, reason: 'no logout call when blocked');
    });

    test('sign_out_with_discard_wipes_pending_ops', () async {
      final h = await signedInWithData();
      await h.db.outboxDao.enqueue(op('createList'));
      h.http.reply('POST', '/auth/logout', 204);
      final r = await h.session.signOut(discardUnsynced: true);
      expect(r, isA<SignedOut>());
      expect(await h.db.outboxDao.pendingCount(), 0);
      expect(h.state, isA<Guest>());
    });
  });

  group('expireSession', () {
    test('expire_session_is_idempotent', () async {
      final h = createAuthHarness(refresh: 'r0', user: _userA, access: 'a0');
      await h.session.restore();
      await h.seedData();
      await h.session.expireSession();
      await h.session.expireSession();
      expect(h.state, isA<Guest>());
      expect(h.store.refresh, isNull);
      expect(h.tokens.value, isNull);
      expect(h.http.calls, isEmpty, reason: 'never calls the server');
      expect(await h.counts(), {
        'lists': 0,
        'items': 0,
        'outbox': 0,
        'card': 0,
        'flyers': 1,
        'payments': 1,
      });
    });
  });
}

class _ThrowingStore extends InMemoryTokenStore {
  @override
  Future<String?> readRefresh() => throw StateError('keystore unavailable');
}

class _FailingUserWriteStore extends InMemoryTokenStore {
  @override
  Future<void> writeUser(SessionUser u) => throw StateError('disk full');
}
