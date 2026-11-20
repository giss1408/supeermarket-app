import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/errors/app_error.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_http.dart';

void tokens(AuthHarness h,
        {String access = 'a1',
        String refresh = 'r1',
        bool mustChange = false}) =>
    h.http.reply('POST', '/v1/login', 200, {
      'access_token': access,
      'refresh_token': refresh,
      'must_change_password': mustChange
    });

Map<String, dynamic> sent(AuthHarness h, String path) =>
    jsonDecode(h.http.callsTo(path).last.body!) as Map<String, dynamic>;

Future<AppError> errorOf(Future<void> f) async {
  try {
    await f;
  } on AppError catch (e) {
    return e;
  }
  fail('expected an AppError');
}

void main() {
  test(
      'sign-in goes to the auth service, then the API profile is read with the token; the account shows the masked phone',
      () async {
    final h = createAuthModeHarness();
    tokens(h);
    h.stubMe(5);
    await h.session.signIn('07 01 02 03 04', 'pw-secret-1');
    expect(sent(h, '/v1/login')['phone'], '0701020304');
    expect(h.http.callsTo('/api/v1/me').single.authorization, 'Bearer a1');
    final user = (h.state as SignedIn).user;
    expect((user.id, user.phone), ('5', '07 •• •• 03 04'));
    expect(h.store.refresh, 'r1');
    expect(h.tokens.value, 'a1');
    expect(h.http.callsTo('/api/v1/auth/login'), isEmpty,
        reason: "the API's own e-mail login is never used");
  });

  test('wrong credentials: the code of the auth service, no session', () async {
    final h = createAuthModeHarness();
    h.http.reply('POST', '/v1/login', 401, {'detail': 'invalid_credentials'});
    final e = await errorOf(h.session.signIn('0701020304', 'x'));
    expect((e as ApiError).code, 'invalid_credentials');
    expect(h.state, isA<Guest>());
  });

  test('an account not activated yet says so (the form then asks for the code)',
      () async {
    final h = createAuthModeHarness();
    h.http.reply('POST', '/v1/login', 403, {'detail': 'not_activated'});
    expect(
        ((await errorOf(h.session.signIn('0701020304', 'x'))) as ApiError).code,
        'not_activated');
  });

  test(
      'sign-up creates the pending account and signs nobody in; the WhatsApp code then activates and signs in with the chosen password',
      () async {
    final h = createAuthModeHarness();
    h.http.reply('POST', '/v1/register', 201, {'status': 'pending_activation'});
    await h.session.registerPhone(
        phone: '0701020304', password: 'pw-secret-1', name: 'Awa');
    expect(h.state, isA<Guest>());
    expect(h.http.callsTo('/v1/login'), isEmpty);
    h.http.reply('POST', '/v1/activate', 200, {'status': 'active'});
    tokens(h);
    h.stubMe(6, name: 'Awa');
    await h.session
        .activate(phone: '0701020304', code: '123456', password: 'pw-secret-1');
    expect(sent(h, '/v1/activate'), {'phone': '0701020304', 'code': '123456'});
    expect(sent(h, '/v1/login')['password'], 'pw-secret-1');
    expect((h.state as SignedIn).user.name, 'Awa');
  });

  test('a wrong activation code opens no session', () async {
    final h = createAuthModeHarness();
    h.http.reply(
        'POST', '/v1/activate', 400, {'detail': 'wrong_activation_code'});
    final e = await errorOf(
        h.session.activate(phone: '0701020304', code: '000000', password: 'x'));
    expect((e as ApiError).code, 'wrong_activation_code');
    expect(h.http.callsTo('/v1/login'), isEmpty);
    expect(h.state, isA<Guest>());
  });

  test(
      'a temporary password asks for a new one; nothing is stored until it is chosen, then the session opens on a renewed token',
      () async {
    final h = createAuthModeHarness();
    tokens(h, access: 'tmp-a', refresh: 'tmp-r', mustChange: true);
    expect(await errorOf(h.session.signIn('0701020304', 'temp-pass')),
        isA<PasswordChangeRequired>());
    expect(h.state, isA<Guest>());
    expect(h.store.refresh, isNull);
    expect(h.http.callsTo('/api/v1/me'), isEmpty,
        reason: 'the API refuses these tokens: it is not even asked');
    h.http.reply('POST', '/v1/password/change', 204);
    h.http.reply('POST', '/v1/refresh', 200,
        {'access_token': 'a2', 'refresh_token': 'r2'});
    h.stubMe(7);
    await h.session.completePasswordChange('brand-new-pass-1');
    expect(sent(h, '/v1/password/change'),
        {'current_password': 'temp-pass', 'new_password': 'brand-new-pass-1'});
    expect(h.http.callsTo('/v1/password/change').single.authorization,
        'Bearer tmp-a');
    expect(sent(h, '/v1/refresh'), {'refresh_token': 'tmp-r'});
    expect(h.store.refresh, 'r2');
    expect(h.http.callsTo('/api/v1/me').single.authorization, 'Bearer a2');
    expect(h.state, isA<SignedIn>());
  });

  test('completing a password change nobody asked for is refused', () async {
    final h = createAuthModeHarness();
    expect(await errorOf(h.session.completePasswordChange('x')),
        isA<UnknownError>());
  });

  test('forgotten password goes to the auth service', () async {
    final h = createAuthModeHarness();
    h.http.reply('POST', '/v1/password/reset-request', 202);
    await h.session.requestPasswordReset('07 01 02 03 04');
    expect(sent(h, '/v1/password/reset-request'),
        {'phone': '0701020304', 'product': 'supermarket'});
  });

  test('sign-out ends the session at the auth service', () async {
    final h = createAuthModeHarness(
        refresh: 'r0',
        user: const SessionUser(
            id: '1', email: '', name: 'A', phone: '07 •• •• 03 04'));
    await h.session.restore();
    h.http.reply('POST', '/v1/logout', 204);
    await h.session.signOut(discardUnsynced: true);
    expect(sent(h, '/v1/logout'), {'refresh_token': 'r0'});
    expect(h.state, isA<Guest>());
    expect(h.http.callsTo('/api/v1/auth/logout'), isEmpty);
  });

  test('restore without a stored user renews at the auth service', () async {
    final h = createAuthModeHarness(refresh: 'r0');
    h.http.reply('POST', '/v1/refresh', 200,
        {'access_token': 'a1', 'refresh_token': 'r1'});
    h.stubMe(2);
    await h.session.restore();
    expect(sent(h, '/v1/refresh'), {'refresh_token': 'r0'});
    expect(h.store.refresh, 'r1');
    expect((h.state as SignedIn).user.id, '2');
  });

  test(
      'a 401 from the API renews the token at the auth service and replays the request once',
      () async {
    final h = createAuthModeHarness(
        refresh: 'r0', user: const SessionUser(id: '1', email: '', name: 'A'));
    await h.session.restore();
    var n = 0;
    h.http.on(
        'GET',
        '/api/v1/me/card',
        (_, __) => n++ == 0
            ? FakeResponse(401, {'code': 'not_authenticated'})
            : FakeResponse(200, {'number': '1', 'barcode_value': '1'}));
    h.http.reply('POST', '/v1/refresh', 200,
        {'access_token': 'a9', 'refresh_token': 'r9'});
    final r = await h.dio.get<Object?>('/api/v1/me/card');
    expect(r.statusCode, 200);
    expect(sent(h, '/v1/refresh'), {'refresh_token': 'r0'});
    expect(h.store.refresh, 'r9');
    expect(h.tokens.value, 'a9');
    expect(h.http.callsTo('/api/v1/auth/refresh'), isEmpty);
  });

  test('a refresh refused by the auth service ends the session', () async {
    final h = createAuthModeHarness(
        refresh: 'r0', user: const SessionUser(id: '1', email: '', name: 'A'));
    await h.session.restore();
    h.http.reply('GET', '/api/v1/me/card', 401, {'code': 'not_authenticated'});
    h.http.reply('POST', '/v1/refresh', 401, {'detail': 'invalid_token'});
    await expectLater(h.dio.get<Object?>('/api/v1/me/card'), throwsA(anything));
    expect(h.state, isA<Guest>());
    expect(h.store.refresh, isNull);
  });
}
