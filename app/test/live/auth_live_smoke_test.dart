@Tags(['live'])
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/auth/token_store.dart';
import 'package:supermarket_app/core/db/database_provider.dart';
import 'package:supermarket_app/core/errors/app_error.dart';

import '../core/db/test_db.dart';
import '../support/in_memory_token_store.dart';

/// SMOKE against the REAL platform (auth service + supermarket API through Caddy), with the app's real code: sign-up, WhatsApp code, sign-in,
/// an API call, a temporary password, sign-out and account deletion. Skipped unless `--dart-define=LIVE_CFG='{"auth":...,"api":...,"boss":...}'`
/// is passed (`platform/tests/smoke_supermarket_app_auth.sh` does it). `boss` is a short-lived back-office token that plays the team sending codes.
const _cfg = String.fromEnvironment('LIVE_CFG');

void main() {
  if (_cfg.isEmpty) {
    test('live smoke (skipped: no LIVE_CFG)', () {},
        skip:
            'needs the platform running, see platform/tests/smoke_supermarket_app_auth.sh');
    return;
  }
  final cfg = jsonDecode(_cfg) as Map<String, dynamic>;
  // Dart does not resolve *.localhost: the platform is reached at 127.0.0.1 and the product is told by the Host header (what Caddy routes on).
  final authHost = cfg['auth_host'] as String;
  final apiHost = cfg['api_host'] as String;
  final team = Dio(BaseOptions(
    baseUrl: cfg['auth'] as String,
    headers: {'Authorization': 'Bearer ${cfg['boss']}', 'Host': authHost},
    contentType: Headers.jsonContentType,
  ));

  /// What the team does: finds the pending request of this number in the relay queue and sends it; returns the secret inside the wa.me link.
  Future<String> teamSends(
      String purpose, String phoneTail, RegExp secret) async {
    final queue = (await team.get<List<dynamic>>('/v1/admin/relay-queue',
            queryParameters: {'status': 'pending'}))
        .data!;
    final item = queue.cast<Map<String, dynamic>>().lastWhere((x) =>
        x['purpose'] == purpose &&
        (x['phone_masked'] as String).endsWith(phoneTail));
    final url = (await team
            .post<Map<String, dynamic>>('/v1/admin/relay/${item['id']}/send'))
        .data!['url'] as String;
    return secret
        .firstMatch(Uri.parse(url).queryParameters['text']!)!
        .group(1)!;
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      apiBaseUrlProvider.overrideWithValue(cfg['api'] as String),
      authBaseUrlProvider.overrideWithValue(cfg['auth'] as String),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      appDatabaseProvider.overrideWithValue(createTestDb()),
    ]);
    addTearDown(c.dispose);
    c.read(authServiceDioProvider).options.headers['Host'] = authHost;
    c.read(dioProvider).options.headers['Host'] = apiHost;
    c.read(bareDioProvider).options.headers['Host'] = apiHost;
    return c;
  }

  Future<AppError> errorOf(Future<void> f) async {
    try {
      await f;
    } on AppError catch (e) {
      return e;
    }
    fail('expected an AppError');
  }

  test(
      'sign-up, WhatsApp code, API call, temporary password, sign-out, deletion',
      () async {
    final phone = '07${DateTime.now().microsecondsSinceEpoch % 100000000}'
        .padRight(10, '0')
        .substring(0, 10);
    const pw = 'Live-pass-2026x';
    final c = container();
    final session = c.read(sessionProvider.notifier);

    await session.registerPhone(phone: phone, password: pw, name: 'Awa Live');
    expect(c.read(sessionProvider), isA<Guest>(),
        reason: 'nobody is signed in by signing up');
    final early = await errorOf(session.signIn(phone, pw));
    expect((early as ApiError).code, 'not_activated');

    final code = await teamSends(
        'activation', phone.substring(8), RegExp(r'\*(\d{6})\*'));
    final wrong = await errorOf(session.activate(
        phone: phone,
        code: code == '000000' ? '111111' : '000000',
        password: pw));
    expect((wrong as ApiError).code, 'wrong_activation_code');
    await session.activate(phone: phone, code: code, password: pw);
    final user = (c.read(sessionProvider) as SignedIn).user;
    expect(user.name, 'Awa Live');
    expect(user.phone,
        '${phone.substring(0, 2)} •• •• ${phone.substring(6, 8)} ${phone.substring(8)}');

    // the API accepts the auth token, and the app's own e-mail endpoints are gone
    final card =
        await c.read(dioProvider).get<Map<String, dynamic>>('/api/v1/me/card');
    expect(card.statusCode, 200);
    expect(card.data!['number'], isNotEmpty);
    final legacy = await Dio(BaseOptions(
            baseUrl: cfg['api'] as String,
            headers: {'Host': apiHost},
            validateStatus: (_) => true))
        .post<Object?>('/api/v1/auth/login', data: {});
    expect(legacy.statusCode, 404);

    // sign out and in again; then a forgotten password: the team sends a temporary one, the app asks for a new one
    expect((await session.signOut(discardUnsynced: true)), isA<SignedOut>());
    await session.signIn(phone, pw);
    await session.signOut(discardUnsynced: true);
    await session.requestPasswordReset(phone);
    final temp = await teamSends(
        'password_reset', phone.substring(8), RegExp(r'\*([a-z0-9]+)\*'));
    expect(await errorOf(session.signIn(phone, temp)),
        isA<PasswordChangeRequired>());
    expect(c.read(sessionProvider), isA<Guest>());
    await session.completePasswordChange('Brand-new-2026x');
    expect(c.read(sessionProvider), isA<SignedIn>());
    await session.signOut(discardUnsynced: true);
    await session.signIn(phone, 'Brand-new-2026x');

    // deleting the account in the supermarket erases her at auth too
    final deleted = await c.read(dioProvider).delete<Object?>('/api/v1/me');
    expect(deleted.statusCode, 204);
    await session.signOut(discardUnsynced: true);
    final gone = await errorOf(session.signIn(phone, 'Brand-new-2026x'));
    expect((gone as ApiError).code, 'invalid_credentials');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
