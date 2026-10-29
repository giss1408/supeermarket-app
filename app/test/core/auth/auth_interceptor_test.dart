import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/auth_interceptor.dart';
import 'package:supermarket_app/core/auth/session.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_http.dart';

const _user = SessionUser(id: '7', email: 'u7@example.ci', name: 'Test');

/// A signed-in harness: refresh token r0, access token a0, user stored.
Future<AuthHarness> signedIn() async {
  final h = createAuthHarness(refresh: 'r0', user: _user, access: 'a0');
  await h.session.restore();
  expect(h.state, isA<SignedIn>());
  return h;
}

/// Protected endpoints answer 200 only for [good]; refresh rotates to a1/r1.
void scriptServer(
  AuthHarness h, {
  String good = 'Bearer a1',
  FakeHandler? refresh,
}) {
  FakeResponse guarded(RequestOptions o, int _) =>
      o.headers['Authorization'] == good
          ? FakeResponse(200, {'ok': true})
          : FakeResponse(401, errorBody('not_authenticated'));
  h.http.on('GET', '/api/v1/lists', guarded);
  h.http.on('GET', '/api/v1/me/card', guarded);
  h.http.on(
    'POST',
    '/api/v1/auth/refresh',
    refresh ??
        (o, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return FakeResponse(200, {'access': 'a1', 'refresh': 'r1'});
        },
  );
}

Future<Object?> failureOf(Future<Object?> f) async {
  try {
    await f;
  } on DioException catch (e) {
    return e;
  }
  return null;
}

void main() {
  test('two_concurrent_401s_trigger_one_refresh_and_both_retry', () async {
    final h = await signedIn();
    scriptServer(h);
    final results = await Future.wait([
      h.dio.get<Object?>('/api/v1/lists'),
      h.dio.get<Object?>('/api/v1/me/card'),
    ]);
    expect(results.map((r) => r.statusCode), [200, 200]);
    expect(h.http.callsTo('/auth/refresh'), hasLength(1));
    expect(h.http.callsTo('/auth/refresh').single.body, contains('r0'));
    for (final path in ['/api/v1/lists', '/api/v1/me/card']) {
      final calls = h.http.callsTo(path);
      expect(calls, hasLength(2), reason: path);
      expect(calls[0].authorization, 'Bearer a0');
      expect(calls[1].authorization, 'Bearer a1');
    }
    expect(h.store.refresh, 'r1');
    expect(h.tokens.value, 'a1');
  });

  test('stale_token_401_retries_with_current_token_without_a_second_refresh',
      () async {
    final h = await signedIn();
    scriptServer(h);
    // While the request is in flight another request refreshed the token.
    h.http.onCall = (c) {
      if (c.path == '/api/v1/lists' && h.tokens.value == 'a0') {
        h.tokens.value = 'a1';
      }
    };
    final r = await h.dio.get<Object?>('/api/v1/lists');
    expect(r.statusCode, 200);
    expect(h.http.callsTo('/auth/refresh'), isEmpty);
    final calls = h.http.callsTo('/api/v1/lists');
    expect(calls.map((c) => c.authorization), ['Bearer a0', 'Bearer a1']);
  });

  test('request_is_retried_at_most_once', () async {
    final h = await signedIn();
    scriptServer(h, good: 'never');
    final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
    expect(e, isA<DioException>());
    expect((e! as DioException).response?.statusCode, 401);
    expect(h.http.callsTo('/api/v1/lists'), hasLength(2));
    expect(h.http.callsTo('/auth/refresh'), hasLength(1));
    // The session is not expired by a post-refresh 401.
    expect(h.state, isA<SignedIn>());
    expect(h.store.refresh, 'r1');
  });

  for (final status in [401, 400]) {
    test(
        'refresh_failure_${status}_expires_session_and_wipes_user_data_but_keeps_public_cache',
        () async {
      final h = await signedIn();
      await h.seedData();
      expect(await h.counts(), {
        'lists': 1,
        'items': 1,
        'outbox': 1,
        'card': 1,
        'flyers': 1,
        'payments': 1
      });
      scriptServer(h,
          refresh: (_, __) =>
              FakeResponse(status, errorBody('not_authenticated')));
      final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
      expect((e! as DioException).response?.statusCode, 401,
          reason: 'original 401 is surfaced');
      expect(h.state, isA<Guest>());
      expect(h.store.refresh, isNull);
      expect(h.store.user, isNull);
      expect(h.tokens.value, isNull);
      expect(await h.counts(), {
        'lists': 0,
        'items': 0,
        'outbox': 0,
        'card': 0,
        'flyers': 1,
        'payments': 1
      });
      expect(h.http.callsTo('/api/v1/lists'), hasLength(1));
    });
  }

  test('concurrent_requests_with_a_dead_refresh_token_expire_once', () async {
    final h = await signedIn();
    scriptServer(h,
        refresh: (_, __) => FakeResponse(401, errorBody('not_authenticated')));
    await Future.wait([
      failureOf(h.dio.get<Object?>('/api/v1/lists')),
      failureOf(h.dio.get<Object?>('/api/v1/me/card')),
    ]);
    expect(h.http.callsTo('/auth/refresh'), hasLength(1));
    expect(h.store.log.where((l) => l == 'clear'), hasLength(1));
    expect(h.state, isA<Guest>());
  });

  test('refresh_network_error_keeps_session_and_does_not_wipe', () async {
    final h = await signedIn();
    await h.seedData();
    var attempt = 0;
    scriptServer(h, refresh: (o, n) {
      attempt = n;
      if (n == 1) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return FakeResponse(200, {'access': 'a1', 'refresh': 'r1'});
    });
    final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
    expect((e! as DioException).type, DioExceptionType.connectionError);
    expect(h.state, isA<SignedIn>());
    expect(h.store.refresh, 'r0');
    expect(h.store.user, _user);
    expect((await h.counts())['lists'], 1);
    expect((await h.counts())['outbox'], 1);
    // A later request retries the refresh and succeeds.
    final r = await h.dio.get<Object?>('/api/v1/lists');
    expect(r.statusCode, 200);
    expect(attempt, 2);
    expect(h.store.refresh, 'r1');
  });

  test('refresh_5xx_keeps_session', () async {
    final h = await signedIn();
    await h.seedData();
    scriptServer(h,
        refresh: (_, __) => FakeResponse(503, errorBody('server_error')));
    final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
    expect((e! as DioException).response?.statusCode, 503);
    expect(h.state, isA<SignedIn>());
    expect(h.store.refresh, 'r0');
    expect((await h.counts())['lists'], 1);
  });

  for (final path in ['login', 'register', 'refresh', 'logout']) {
    test('auth_endpoints_are_never_refreshed_on_401: $path', () async {
      final h = await signedIn();
      h.http.reply(
          'POST', '/api/v1/auth/$path', 401, errorBody('not_authenticated'));
      h.http.reply(
          'POST', '/api/v1/auth/refresh', 401, errorBody('not_authenticated'));
      final e = await failureOf(h.dio.post<Object?>('/api/v1/auth/$path'));
      expect((e! as DioException).response?.statusCode, 401, reason: path);
      expect(h.http.callsTo('/api/v1/auth/$path'), hasLength(1), reason: path);
      expect(
          h.http.callsTo('/auth/refresh'), hasLength(path == 'refresh' ? 1 : 0),
          reason: path);
      expect(h.state, isA<SignedIn>(), reason: path);
    });
  }

  test('no_refresh_token_means_401_is_just_rejected', () async {
    final h = createAuthHarness();
    scriptServer(h);
    final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
    expect((e! as DioException).response?.statusCode, 401);
    expect(h.http.calls, hasLength(1));
    expect(h.state, isA<Guest>());
  });

  test('authorization_header_added_only_for_non_auth_endpoints', () async {
    final h = await signedIn();
    h.http.reply('GET', '/api/v1/lists', 200);
    for (final p in ['login', 'register', 'refresh', 'logout']) {
      h.http.reply('POST', '/api/v1/auth/$p', 200);
      await h.dio.post<Object?>('/api/v1/auth/$p');
    }
    await h.dio.get<Object?>('/api/v1/lists');
    final byPath = {for (final c in h.http.calls) c.path: c.authorization};
    expect(byPath['/api/v1/lists'], 'Bearer a0');
    for (final p in ['login', 'register', 'refresh', 'logout']) {
      expect(byPath['/api/v1/auth/$p'], isNull, reason: p);
    }
  });

  test('no_token_means_no_authorization_header', () async {
    final h = createAuthHarness();
    h.http.reply('GET', '/api/v1/lists', 200);
    await h.dio.get<Object?>('/api/v1/lists');
    expect(h.http.calls.single.authorization, isNull);
  });

  test('rotated_refresh_token_written_before_access_token_is_used', () async {
    final h = await signedIn();
    scriptServer(h);
    final seen = <String?>[];
    h.http.onCall = (c) {
      if (c.path == '/api/v1/lists' && c.authorization == 'Bearer a1') {
        seen.add(h.store.refresh);
      }
    };
    await h.dio.get<Object?>('/api/v1/lists');
    expect(seen, ['r1'], reason: 'store already rotated at the retry');
    expect(h.store.log, contains('writeRefresh:r1'));
  });

  test('refresh_result_is_discarded_if_the_user_signed_out_meanwhile',
      () async {
    final h = await signedIn();
    scriptServer(h, refresh: (_, __) async {
      await h.session.expireSession(); // sign-out during the refresh call
      return FakeResponse(200, {'access': 'a1', 'refresh': 'r1'});
    });
    final e = await failureOf(h.dio.get<Object?>('/api/v1/lists'));
    expect((e! as DioException).response?.statusCode, 401);
    expect(h.store.refresh, isNull, reason: 'session not resurrected');
    expect(h.tokens.value, isNull);
    expect(h.state, isA<Guest>());
  });

  test('no_generated_auth_interceptors_attached', () {
    final h = createAuthHarness();
    for (final dio in [h.dio, h.container.read(bareDioProvider)]) {
      // Build the generated client the way the app does.
      expect(
        dio.interceptors.whereType<OAuthInterceptor>(),
        isEmpty,
      );
    }
    final apiDio = h.container.read(apiClientProvider).dio;
    final bare = h.container.read(bareApiClientProvider).dio;
    for (final dio in [apiDio, bare]) {
      expect(dio.interceptors.whereType<OAuthInterceptor>(), isEmpty);
      expect(dio.interceptors.whereType<BearerAuthInterceptor>(), isEmpty);
      expect(dio.interceptors.whereType<BasicAuthInterceptor>(), isEmpty);
      expect(dio.interceptors.whereType<ApiKeyAuthInterceptor>(), isEmpty);
    }
    expect(apiDio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    expect(bare.interceptors.whereType<AuthInterceptor>(), isEmpty);
  });
}
