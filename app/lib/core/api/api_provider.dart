import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final dioProvider = Provider<Dio>(
  (ref) => createDio(baseUrl: AppConfig.apiBaseUrl),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(dio: ref.watch(dioProvider)),
);
