import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';

void main() {
  group('createDio', () {
    test('throws StateError for an empty base URL', () {
      expect(() => createDio(baseUrl: ''), throwsStateError);
    });

    test('configures base URL, timeouts and headers', () {
      final dio = createDio(baseUrl: 'https://api.example.com/api/v1');
      final o = dio.options;
      expect(o.baseUrl, 'https://api.example.com/api/v1');
      expect(o.connectTimeout, const Duration(seconds: 15));
      expect(o.receiveTimeout, const Duration(seconds: 30));
      expect(o.headers['Accept-Language'], 'fr');
      expect(o.headers['Accept'], 'application/json');
      expect(o.contentType, Headers.jsonContentType);
      expect(o.responseType, ResponseType.json);
    });

    test('timeouts can be overridden', () {
      final dio = createDio(
        baseUrl: 'https://x',
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 2),
      );
      expect(dio.options.connectTimeout, const Duration(seconds: 1));
      expect(dio.options.receiveTimeout, const Duration(seconds: 2));
    });
  });

  group('providers', () {
    test('dioProvider fails loudly when API_BASE_URL is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(dioProvider), throwsStateError);
    });

    test('overriding dioProvider feeds apiClientProvider', () {
      final dio = createDio(baseUrl: 'https://api.example.com');
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      expect(container.read(dioProvider), same(dio));
      expect(container.read(apiClientProvider).dio, same(dio));
    });
  });
}
