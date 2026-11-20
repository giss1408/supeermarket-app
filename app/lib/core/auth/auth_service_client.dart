import 'dart:convert';

import 'package:dio/dio.dart';

import '../errors/app_error.dart';
import '../errors/error_mapper.dart';

/// Tokens issued by the auth service.
class AuthTokens {
  const AuthTokens({
    required this.access,
    required this.refresh,
    this.mustChangePassword = false,
  });

  final String access;
  final String refresh;

  /// Signed in with a temporary password (sent by the team on WhatsApp): the API refuses these tokens until a new password is chosen.
  final bool mustChangePassword;
}

/// The platform auth service, the one place people sign up and sign in (phone + password). Hand-written: it is not part of this API's contract.
/// Every method throws a raw [DioException]; callers map it with [mapAuthError].
class AuthServiceClient {
  AuthServiceClient(this._dio);

  static const product = 'supermarket';

  final Dio _dio;

  static String digits(String phone) => phone.replaceAll(RegExp(r'\s+'), '');

  AuthTokens _tokens(Object? data) {
    final Map<Object?, Object?> map =
        data is Map ? data : const <Object?, Object?>{};
    final access = map['access_token'];
    final refresh = map['refresh_token'];
    if (access is! String || refresh is! String) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1'),
        error: 'unusable answer',
      );
    }
    return AuthTokens(
      access: access,
      refresh: refresh,
      mustChangePassword: map['must_change_password'] == true,
    );
  }

  Future<AuthTokens> login(
      {required String phone, required String password}) async {
    final r = await _dio.post<Object?>(
      '/v1/login',
      data: jsonEncode({
        'phone': digits(phone),
        'password': password,
        'product': product,
        'app': 'customer',
      }),
    );
    return _tokens(r.data);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final r = await _dio.post<Object?>('/v1/refresh',
        data: jsonEncode({'refresh_token': refreshToken}));
    return _tokens(r.data);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<Object?>('/v1/logout',
        data: jsonEncode({'refresh_token': refreshToken}));
  }

  /// Creates a pending account: nobody can sign in until the team's WhatsApp code is typed ([activate]).
  Future<void> register(
      {required String phone,
      required String password,
      required String name}) async {
    await _dio.post<Object?>(
      '/v1/register',
      data: jsonEncode({
        'phone': digits(phone),
        'password': password,
        'display_name': name.trim(),
        'product': product,
        'consent': true,
      }),
    );
  }

  Future<void> activate({required String phone, required String code}) async {
    await _dio.post<Object?>(
      '/v1/activate',
      data: jsonEncode({
        'phone': digits(phone),
        'code': code.replaceAll(RegExp(r'\s+'), ''),
      }),
    );
  }

  /// "Forgotten password": the team sends a temporary one on WhatsApp. The answer never says whether the number has an account.
  Future<void> requestPasswordReset(String phone) async {
    await _dio.post<Object?>('/v1/password/reset-request',
        data: jsonEncode({'phone': digits(phone), 'product': product}));
  }

  Future<void> changePassword(
      {required String access,
      required String current,
      required String next}) async {
    await _dio.post<Object?>(
      '/v1/password/change',
      data: jsonEncode({'current_password': current, 'new_password': next}),
      options: Options(headers: {'Authorization': 'Bearer $access'}),
    );
  }
}

/// Auth-service answers carry their code in `detail` ({"detail": "invalid_credentials"}); it becomes the [ApiError] code the screens branch on.
AppError mapAuthError(DioException e) {
  final response = e.response;
  final data = response?.data;
  if (response != null && data is Map && data['detail'] is String) {
    return ApiError(
      code: data['detail'] as String,
      status: response.statusCode ?? 0,
      fields: const {},
    );
  }
  return mapDioException(e);
}

/// "07 •• •• 03 04" from the digits typed, the way the account is shown.
String maskPhone(String typed) {
  final d = typed.replaceAll(RegExp(r'\D'), '');
  final ten = d.length > 10 ? d.substring(d.length - 10) : d;
  if (ten.length < 10) return '•• •• ••';
  return '${ten.substring(0, 2)} •• •• ${ten.substring(6, 8)} ${ten.substring(8, 10)}';
}
