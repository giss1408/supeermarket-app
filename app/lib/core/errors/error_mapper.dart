import 'dart:convert';

import 'package:api_client/api_client.dart' show ErrorResponse;
import 'package:dio/dio.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'app_error.dart';

/// Converts a [DioException] into an [AppError].
///
/// A response whose body is not the API error shape (HTML from a proxy, odd
/// JSON) still proves the server was reached, so it becomes
/// `ApiError(code: 'unknown', status: <status>)`; without a valid HTTP status
/// it is an [UnknownError].
AppError mapDioException(DioException e) {
  final response = e.response;
  if (response != null) {
    final status = response.statusCode;
    if (status == null) return UnknownError(e);
    final parsed = _parse(response.data);
    if (parsed != null) {
      return ApiError(
        code: parsed.code,
        status: status,
        fields: parsed.fields,
        detail: parsed.detail,
      );
    }
    return ApiError(code: 'unknown', status: status, fields: const {});
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const AppTimeoutError();
    case DioExceptionType.connectionError:
      return const NetworkError();
    case DioExceptionType.unknown:
      final inner = e.error;
      if (_isSocket(inner)) {
        return const NetworkError();
      }
      return UnknownError(e);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
      return UnknownError(e);
  }
}

// dart:io is unavailable on web; match by runtime type name instead.
bool _isSocket(Object? o) {
  final n = o?.runtimeType.toString() ?? '';
  return n == 'SocketException' ||
      n == 'HttpException' ||
      n == 'HandshakeException' ||
      n == 'OSError';
}

ErrorResponse? _parse(Object? data) {
  try {
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is Map<String, dynamic>) {
      return ErrorResponse.fromJson(decoded);
    }
  } on Object {
    // Not the error shape.
  }
  return null;
}

/// French, user-facing message for [e]. The server `detail` is never used.
String userMessage(AppError e, AppLocalizations l) => switch (e) {
      NetworkError() => l.errorNetwork,
      AppTimeoutError() => l.errorTimeout,
      UnknownError() => l.errorGeneric,
      ApiError(:final code) => switch (code) {
          'validation_error' => l.errorValidation,
          'not_authenticated' => l.errorNotAuthenticated,
          'permission_denied' => l.errorPermissionDenied,
          'not_found' => l.errorNotFound,
          'throttled' => l.errorThrottled,
          'conflict' => l.errorConflict,
          'server_error' => l.errorServer,
          'csrf_failed' => l.errorCsrf,
          'bad_request' => l.errorBadRequest,
          'unsupported_media_type' => l.errorUnsupportedMediaType,
          _ => l.errorGeneric,
        },
    };
