import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';

import 'token_store.dart';

/// In-memory holder of the access token. It is never persisted.
class AccessTokenHolder {
  String? value;
}

/// `RequestOptions.extra` flag marking a request already retried once.
const authRetriedKey = 'auth_retried';

const _authPaths = [
  '/api/v1/auth/login',
  '/api/v1/auth/register',
  '/api/v1/auth/refresh',
  '/api/v1/auth/logout',
];

bool isAuthEndpoint(RequestOptions o) {
  final path = o.uri.path;
  return _authPaths.any(path.endsWith);
}

class _RefreshFailed implements Exception {
  _RefreshFailed(this.error, {required this.expired});
  final DioException? error;

  /// True when the server definitively rejected the refresh token.
  final bool expired;
}

/// Adds the bearer token and, on a 401 from a non-auth endpoint, runs ONE
/// shared token refresh and retries the request at most once.
///
/// Sessions are restored offline without any request, so the access token is
/// absent after a cold start: the first authenticated request gets a 401 and
/// this interceptor refreshes lazily using the stored refresh token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.bareDio,
    required this.tokens,
    required this.store,
    required this.onSessionExpired,
  });

  /// The Dio this interceptor is attached to (used to retry).
  final Dio dio;

  /// Interceptor-free Dio with the same options, used for the refresh call.
  final Dio bareDio;
  final AccessTokenHolder tokens;
  final TokenStore store;

  /// Called once when the refresh token is definitively rejected.
  final Future<void> Function() onSessionExpired;

  Future<String>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = tokens.value;
    if (access != null && !isAuthEndpoint(options)) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.type != DioExceptionType.badResponse ||
        err.response?.statusCode != 401 ||
        isAuthEndpoint(req) ||
        req.extra[authRetriedKey] == true) {
      return handler.next(err);
    }
    try {
      if (_refreshing == null && await store.readRefresh() == null) {
        // No refresh token: the user is a guest, nothing to refresh.
        return handler.next(err);
      }
      // No await between this check and starting/joining the refresh, so
      // concurrent 401s cannot start two refreshes.
      final sent = _bearerOf(req);
      final current = tokens.value;
      if (_refreshing != null || current == null || sent == current) {
        await _refreshOnce();
      }
      // else: another request already refreshed; retry with the new token.
      handler.resolve(await _retry(req));
    } on _RefreshFailed catch (f) {
      if (f.expired || f.error == null) return handler.next(err);
      handler.next(f.error!.copyWith(requestOptions: req));
    } on DioException catch (e) {
      handler.next(e);
    } on Object catch (e, s) {
      handler.next(DioException(requestOptions: req, error: e, stackTrace: s));
    }
  }

  String? _bearerOf(RequestOptions o) {
    final h = o.headers['Authorization'];
    if (h is String && h.startsWith('Bearer ')) return h.substring(7);
    return null;
  }

  Future<Response<dynamic>> _retry(RequestOptions req) {
    final copy = req.copyWith(
      extra: {...req.extra, authRetriedKey: true},
      headers: {...req.headers}..remove('Authorization'),
    );
    return dio.fetch<dynamic>(copy);
  }

  /// All concurrent callers share a single refresh future.
  Future<String> _refreshOnce() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final future = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<String> _doRefresh() async {
    final sentRefresh = await store.readRefresh();
    if (sentRefresh == null) throw _RefreshFailed(null, expired: false);
    final TokenRefresh result;
    try {
      final response = await AuthApi(bareDio).authRefreshCreate(
        tokenRefreshRequest: TokenRefreshRequest(refresh: sentRefresh),
      );
      final data = response.data;
      if (data == null) throw _RefreshFailed(null, expired: false);
      result = data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final rejected = e.type == DioExceptionType.badResponse &&
          (status == 401 || status == 400);
      if (rejected) {
        await onSessionExpired();
        throw _RefreshFailed(e, expired: true);
      }
      throw _RefreshFailed(e, expired: false);
    }
    // The user may have signed out / switched while the call was in flight:
    // never resurrect a cleared session with the rotated token.
    if (await store.readRefresh() != sentRefresh) {
      throw _RefreshFailed(null, expired: false);
    }
    // Rotated refresh token FIRST, then the access token becomes usable.
    await store.writeRefresh(result.refresh);
    tokens.value = result.access;
    return result.access;
  }
}
