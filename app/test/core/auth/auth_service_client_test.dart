import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/auth_service_client.dart';
import 'package:supermarket_app/core/errors/app_error.dart';

import '../../support/fake_http.dart';

({AuthServiceClient client, FakeAdapter http}) make() {
  final http = FakeAdapter();
  final dio = createDio(baseUrl: 'https://auth.test')..httpClientAdapter = http;
  return (client: AuthServiceClient(dio), http: http);
}

Map<String, dynamic> body(FakeAdapter http, String path) =>
    jsonDecode(http.callsTo(path).single.body!) as Map<String, dynamic>;

void main() {
  test(
      'sign-in sends the phone without spaces, the product and the customer app',
      () async {
    final t = make();
    t.http.reply('POST', '/v1/login', 200, {
      'access_token': 'a',
      'refresh_token': 'r',
      'must_change_password': false
    });
    final tokens =
        await t.client.login(phone: '07 01 02 03 04', password: 'pw');
    expect((tokens.access, tokens.refresh, tokens.mustChangePassword),
        ('a', 'r', false));
    expect(body(t.http, '/v1/login'), {
      'phone': '0701020304',
      'password': 'pw',
      'product': 'supermarket',
      'app': 'customer'
    });
  });

  test('a temporary password is reported on the tokens', () async {
    final t = make();
    t.http.reply('POST', '/v1/login', 200, {
      'access_token': 'a',
      'refresh_token': 'r',
      'must_change_password': true
    });
    expect(
        (await t.client.login(phone: '0701020304', password: 'tmp'))
            .mustChangePassword,
        isTrue);
  });

  test('sign-up creates a pending account with consent; the code activates it',
      () async {
    final t = make();
    t.http.reply('POST', '/v1/register', 201, {'status': 'pending_activation'});
    t.http.reply('POST', '/v1/activate', 200, {'status': 'active'});
    await t.client.register(
        phone: '07 01 02 03 04', password: 'pw-secret-1', name: '  Awa ');
    expect(body(t.http, '/v1/register'), {
      'phone': '0701020304',
      'password': 'pw-secret-1',
      'display_name': 'Awa',
      'product': 'supermarket',
      'consent': true
    });
    await t.client.activate(phone: '0701020304', code: '123 456');
    expect(body(t.http, '/v1/activate'),
        {'phone': '0701020304', 'code': '123456'});
  });

  test(
      'refresh, logout, reset request and password change use the documented bodies',
      () async {
    final t = make();
    t.http.reply('POST', '/v1/refresh', 200,
        {'access_token': 'a2', 'refresh_token': 'r2'});
    t.http.reply('POST', '/v1/logout', 204);
    t.http.reply('POST', '/v1/password/reset-request', 202);
    t.http.reply('POST', '/v1/password/change', 204);
    expect((await t.client.refresh('r1')).refresh, 'r2');
    expect(body(t.http, '/v1/refresh'), {'refresh_token': 'r1'});
    await t.client.logout('r2');
    expect(body(t.http, '/v1/logout'), {'refresh_token': 'r2'});
    await t.client.requestPasswordReset('07 01 02 03 04');
    expect(body(t.http, '/v1/password/reset-request'),
        {'phone': '0701020304', 'product': 'supermarket'});
    await t.client
        .changePassword(access: 'tok', current: 'old', next: 'new-pass-1');
    expect(body(t.http, '/v1/password/change'),
        {'current_password': 'old', 'new_password': 'new-pass-1'});
    expect(t.http.callsTo('/v1/password/change').single.authorization,
        'Bearer tok');
  });

  test('an unusable answer is an error, not a half session', () async {
    final t = make();
    t.http.reply('POST', '/v1/login', 200, {'oops': true});
    await expectLater(t.client.login(phone: '0701020304', password: 'pw'),
        throwsA(isA<DioException>()));
  });

  test(
      'the auth service puts its code in `detail`: it becomes the ApiError code',
      () async {
    final t = make();
    t.http.reply('POST', '/v1/login', 401, {'detail': 'invalid_credentials'});
    try {
      await t.client.login(phone: '0701020304', password: 'x');
      fail('expected a DioException');
    } on DioException catch (e) {
      final err = mapAuthError(e);
      expect(err, isA<ApiError>());
      expect((err as ApiError).code, 'invalid_credentials');
      expect(err.status, 401);
    }
  });

  test('the phone is masked the way the account is shown', () {
    expect(maskPhone('07 01 02 03 04'), '07 •• •• 03 04');
    expect(maskPhone('+225 07 01 02 03 04'), '07 •• •• 03 04');
    expect(maskPhone('12'), '•• •• ••');
  });
}
