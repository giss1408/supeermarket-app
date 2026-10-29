import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart' as keys;

import '../../support/auth_harness.dart';
import '../../support/fake_http.dart';

const _a = SessionUser(id: '1', email: 'u1@example.ci', name: 'A');
const _b = SessionUser(id: '2', email: 'u2@example.ci', name: 'B');

Future<AuthHarness> signedInAsA({String? access = 'a0'}) async {
  final h = createAuthHarness(refresh: 'r0', user: _a, access: access);
  await h.session.restore();
  expect(h.state, isA<SignedIn>());
  return h;
}

/// Protected endpoints answer 200 only for [good]; the refresh response is
/// produced by [refresh] (default: rotate to a1/r1) after signalling
/// [started].
Completer<void> script(
  AuthHarness h, {
  String good = 'Bearer a1',
  FakeHandler? refresh,
}) {
  final started = Completer<void>();
  FakeResponse guarded(RequestOptions o, int _) =>
      o.headers['Authorization'] == good
          ? FakeResponse(200, {'ok': true})
          : FakeResponse(401, errorBody('not_authenticated'));
  h.http.on('GET', '/api/v1/lists', guarded);
  h.http.on('GET', '/api/v1/me/card', guarded);
  h.http.on('POST', '/api/v1/auth/refresh', (o, n) async {
    if (!started.isCompleted) started.complete();
    if (refresh != null) return refresh(o, n);
    return FakeResponse(200, {'access': 'a1', 'refresh': 'r1'});
  });
  return started;
}

Future<DioException?> failure(Future<Object?> f) async {
  try {
    await f;
  } on DioException catch (e) {
    return e;
  }
  return null;
}

/// Signs in as B (user id 2) through the real controller.
Future<void> signInAsB(AuthHarness h) async {
  h.stubLogin(access: 'bAccess', refresh: 'bRefresh');
  h.stubMe(2, name: 'B');
  await h.session.signIn('u2@example.ci', 'pw');
}

void main() {
  test('refresh_completing_after_sign_out_writes_nothing', () async {
    final h = await signedInAsA();
    final release = Completer<FakeResponse>();
    final started = script(h, refresh: (_, __) => release.future);
    final req = failure(h.dio.get<Object?>('/api/v1/lists'));
    await started.future;
    await h.session.signOut(discardUnsynced: true);
    release.complete(FakeResponse(200, {'access': 'a1', 'refresh': 'r1'}));
    final e = await req;
    expect(e?.response?.statusCode, 401);
    expect(h.store.refresh, isNull);
    expect(h.store.log.where((l) => l.startsWith('writeRefresh')), isEmpty);
    expect(h.tokens.value, isNull);
    expect(h.state, isA<Guest>());
    h.http.reply('GET', '/api/v1/stores', 200);
    await h.dio.get<Object?>('/api/v1/stores');
    expect(h.http.callsTo('/api/v1/stores').single.authorization, isNull);
    expect(h.http.callsTo('/api/v1/lists'), hasLength(1), reason: 'no retry');
  });

  test('refresh_paused_inside_write_while_expire_runs_ends_cleared', () async {
    final h = await signedInAsA();
    script(h);
    final inWrite = Completer<void>();
    final releaseWrite = Completer<void>();
    h.store.beforeWriteRefresh = (_) async {
      inWrite.complete();
      await releaseWrite.future;
    };
    final req = failure(h.dio.get<Object?>('/api/v1/lists'));
    await inWrite.future;
    final expired = h.session.expireSession();
    releaseWrite.complete();
    await expired;
    await req;
    expect(h.state, isA<Guest>());
    expect(h.store.refresh, isNull);
    expect(h.store.user, isNull);
    expect(h.tokens.value, isNull);
  });

  test('refresh_completing_after_account_switch_keeps_users_B_tokens',
      () async {
    final h = await signedInAsA();
    final release = Completer<FakeResponse>();
    final started = script(h, refresh: (_, __) => release.future);
    final req = failure(h.dio.get<Object?>('/api/v1/lists'));
    await started.future;
    await signInAsB(h); // no sign-out in between
    release.complete(FakeResponse(200, {'access': 'a1', 'refresh': 'r1'}));
    final e = await req;
    expect(e?.response?.statusCode, 401);
    expect(h.store.refresh, 'bRefresh');
    expect(h.tokens.value, 'bAccess');
    expect((h.state as SignedIn).user.id, '2');
    expect(h.store.log.join(), isNot(contains('r1')));
    expect(h.tokens.value, isNot('a1'));
  });

  test('rejected_stale_refresh_after_switch_does_not_expire_the_new_session',
      () async {
    final h = await signedInAsA();
    final release = Completer<FakeResponse>();
    final started = script(h, refresh: (_, __) => release.future);
    final req = failure(h.dio.get<Object?>('/api/v1/lists'));
    await started.future;
    await signInAsB(h);
    await h.seedData(); // B's local data
    release.complete(FakeResponse(401, errorBody('not_authenticated')));
    final e = await req;
    expect(e?.response?.statusCode, 401);
    expect(h.state, isA<SignedIn>());
    expect((h.state as SignedIn).user.id, '2');
    expect(h.store.refresh, 'bRefresh');
    expect(h.store.user?.id, '2');
    expect(h.tokens.value, 'bAccess');
    expect(await h.counts(), {
      'lists': 1,
      'items': 1,
      'outbox': 1,
      'card': 1,
      'flyers': 1,
      'payments': 1,
    });
  });

  test('request_built_under_old_epoch_is_not_retried_with_new_users_token',
      () async {
    final h = await signedInAsA();
    script(h, good: 'Bearer bAccess');
    final hold = Completer<void>();
    final sent = Completer<void>();
    h.http.on('GET', '/api/v1/lists', (o, _) async {
      sent.complete();
      await hold.future;
      return FakeResponse(401, errorBody('not_authenticated'));
    });
    final req = failure(h.dio.get<Object?>('/api/v1/lists'));
    await sent.future;
    await signInAsB(h);
    hold.complete();
    final e = await req;
    expect(e?.response?.statusCode, 401);
    expect(h.http.callsTo('/api/v1/lists'), hasLength(1));
    expect(h.http.callsTo('/api/v1/lists').single.authorization, 'Bearer a0');
    expect(h.http.callsTo('/auth/refresh'), isEmpty);
    expect(h.tokens.value, 'bAccess');
  });

  test('sign_in_orders_wipe_then_last_user_id_then_store_writes', () async {
    final h = createAuthHarness();
    h.stubLogin(access: 'a1', refresh: 'r1');
    h.stubMe(1);
    await h.session.signIn('u1@example.ci', 'pw');
    await h.seedData();
    h.stubLogin(access: 'bAccess', refresh: 'bRefresh');
    h.stubMe(2, name: 'B');

    final log = <String>[];
    Future<String> snap() async {
      final last = await h.db.syncMetaDao.get(keys.lastUserId);
      final lists = (await h.db.listsDao.allLists()).length;
      return 'lists=$lists,last=$last';
    }

    h.store.beforeWriteRefresh =
        (_) async => log.add('writeRefresh[${await snap()}]');
    h.store.beforeWriteUser = (_) async {
      log.add('writeUser[${await snap()},refresh=${h.store.refresh}]');
    };
    h.container.listen(sessionProvider, (_, next) {
      if (next is SignedIn) {
        log.add('state[access=${h.tokens.value},refresh=${h.store.refresh},'
            'user=${h.store.user?.id}]');
      }
    });
    await h.session.signIn('u2@example.ci', 'pw');
    expect(log, [
      'writeRefresh[lists=0,last=2]', // wipe, then last_user_id, then store
      'writeUser[lists=0,last=2,refresh=bRefresh]',
      'state[access=bAccess,refresh=bRefresh,user=2]',
    ]);
  });

  test('restore_reconciles_divergent_last_user_id_by_wiping_before_exposing',
      () async {
    final h = createAuthHarness(refresh: 'r0', user: _b);
    await h.seedData();
    await h.db.syncMetaDao.set(keys.lastUserId, '1');
    var listsWhenExposed = -1;
    h.container.listen(sessionProvider, (_, next) async {
      if (next is SignedIn) {
        listsWhenExposed = (await h.db.listsDao.allLists()).length;
      }
    });
    await h.session.restore();
    await Future<void>.delayed(Duration.zero);
    expect((h.state as SignedIn).user.id, '2');
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
    expect(h.http.calls, isEmpty);
  });

  test('restore_with_null_last_user_id_sets_it_without_wiping', () async {
    final h = createAuthHarness(refresh: 'r0', user: _b);
    await h.seedData();
    await h.db.syncMetaDao.remove(keys.lastUserId);
    await h.session.restore();
    expect(h.state, isA<SignedIn>());
    expect((await h.counts())['lists'], 1);
    expect(await h.db.syncMetaDao.get(keys.lastUserId), '2');
  });

  test('late_restore_failure_does_not_clear_a_newer_session', () async {
    final h = createAuthHarness(refresh: 'r0'); // token but no stored user
    final release = Completer<void>();
    final started = Completer<void>();
    h.http.on('POST', '/auth/refresh', (o, _) async {
      started.complete();
      await release.future;
      throw DioException(
          requestOptions: o, type: DioExceptionType.connectionTimeout);
    });
    final restoring = h.session.restore();
    await started.future;
    await signInAsB(h);
    release.complete();
    await restoring;
    expect(h.state, isA<SignedIn>());
    expect((h.state as SignedIn).user.id, '2');
    expect(h.store.refresh, 'bRefresh');
    expect(h.store.user?.id, '2');
    expect(h.tokens.value, 'bAccess');
  });

  test('late_offline_restore_does_not_overwrite_a_newer_session', () async {
    final h = createAuthHarness(refresh: 'r0', user: _a);
    final inRead = Completer<void>();
    final release = Completer<void>();
    h.store.beforeReadUser = () async {
      if (!inRead.isCompleted) {
        inRead.complete();
        await release.future;
      }
    };
    final restoring = h.session.restore();
    await inRead.future;
    await signInAsB(h);
    release.complete();
    await restoring;
    expect((h.state as SignedIn).user.id, '2');
    expect(h.store.user?.id, '2');
    expect(await h.db.syncMetaDao.get(keys.lastUserId), '2');
  });

  test('two_concurrent_401s_with_no_access_token_trigger_one_refresh',
      () async {
    final h = await signedInAsA(access: null); // as after an offline restore
    script(h);
    final results = await Future.wait([
      h.dio.get<Object?>('/api/v1/lists'),
      h.dio.get<Object?>('/api/v1/me/card'),
    ]);
    expect(results.map((r) => r.statusCode), [200, 200]);
    expect(h.http.callsTo('/auth/refresh'), hasLength(1));
    for (final p in ['/api/v1/lists', '/api/v1/me/card']) {
      final calls = h.http.callsTo(p);
      expect(calls.map((c) => c.authorization), [null, 'Bearer a1']);
    }
    expect(h.store.refresh, 'r1');
  });

  test('rotated_refresh_token_written_before_access_token_is_set', () async {
    final h = await signedInAsA();
    script(h);
    final accessWhenWriting = <String?>[];
    h.store.beforeWriteRefresh =
        (_) async => accessWhenWriting.add(h.tokens.value);
    await h.dio.get<Object?>('/api/v1/lists');
    expect(accessWhenWriting, ['a0'],
        reason: 'the access token must still be the OLD one during the write');
    expect(h.tokens.value, 'a1');
  });
}
