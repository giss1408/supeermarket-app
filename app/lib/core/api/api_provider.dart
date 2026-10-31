import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_interceptor.dart';
import '../auth/auth_session_guard.dart';
import '../auth/session_controller.dart';
import '../auth/token_store.dart';
import '../config/app_config.dart';

/// Builds the app's Dio. An empty [baseUrl] (missing `API_BASE_URL`
/// dart-define) fails loudly instead of producing a client that calls nowhere.
Dio createDio({
  required String baseUrl,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 30),
}) {
  if (baseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL is empty. Pass --dart-define-from-file=env/<name>.json.',
    );
  }
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {
        Headers.acceptHeader: Headers.jsonContentType,
        'Accept-Language': 'fr',
      },
    ),
  );
}

/// Test seam: flip [online] to false and every request made through the app's
/// Dio instances fails as if the device had no network. Always online in
/// production; only the integration test closes it.
class NetworkGate {
  bool online = true;
}

final networkGateProvider = Provider<NetworkGate>((ref) => NetworkGate());

/// Rejects requests with a connection error while the gate is closed.
class NetworkGateInterceptor extends Interceptor {
  NetworkGateInterceptor(this._gate);

  final NetworkGate _gate;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_gate.online) return handler.next(options);
    handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'NetworkGate is closed',
      ),
      true,
    );
  }
}

/// Base URL of the API; overridable in tests.
final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

/// Dio WITHOUT interceptors: login, register, logout and refresh calls, so
/// they can never trigger token handling.
final bareDioProvider = Provider<Dio>((ref) {
  final dio = createDio(baseUrl: ref.watch(apiBaseUrlProvider));
  dio.interceptors.add(NetworkGateInterceptor(ref.watch(networkGateProvider)));
  return dio;
});

/// In-memory access token shared by the session controller and the
/// interceptor. Never persisted.
final accessTokenProvider = Provider<AccessTokenHolder>(
  (ref) => AccessTokenHolder(),
);

/// The app's Dio: our [AuthInterceptor] adds the bearer token and refreshes
/// it on 401.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(baseUrl: ref.watch(apiBaseUrlProvider));
  dio.interceptors.add(NetworkGateInterceptor(ref.watch(networkGateProvider)));
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      bareDio: ref.watch(bareDioProvider),
      tokens: ref.watch(accessTokenProvider),
      store: ref.watch(tokenStoreProvider),
      guard: ref.watch(authSessionGuardProvider),
      onSessionExpired: (epoch) =>
          ref.read(sessionProvider.notifier).expireIfCurrent(epoch),
    ),
  );
  return dio;
});

// The generated ApiClient installs its own four auth interceptors when no
// list is given; an explicit empty list keeps token handling in
// [AuthInterceptor] only.
const _noInterceptors = <Interceptor>[];

final apiClientProvider = Provider<ApiClient>(
  (ref) =>
      ApiClient(dio: ref.watch(dioProvider), interceptors: _noInterceptors),
);

/// Client on the bare Dio (auth endpoints).
final bareApiClientProvider = Provider<ApiClient>(
  (ref) =>
      ApiClient(dio: ref.watch(bareDioProvider), interceptors: _noInterceptors),
);
