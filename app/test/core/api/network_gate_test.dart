import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';

void main() {
  test('a closed gate fails requests as a connection error, an open one passes',
      () async {
    final container = ProviderContainer(overrides: [
      apiBaseUrlProvider.overrideWithValue('http://127.0.0.1:1'),
    ]);
    addTearDown(container.dispose);
    final gate = container.read(networkGateProvider);
    final dio = container.read(bareDioProvider);

    gate.online = false;
    await expectLater(
      dio.get<void>('/x'),
      throwsA(isA<DioException>()
          .having((e) => e.type, 'type', DioExceptionType.connectionError)),
    );

    // Open again: the request now really leaves (nothing listens on port 1,
    // so it fails for a different reason than the gate).
    gate.online = true;
    await expectLater(
      dio.get<void>('/x'),
      throwsA(isA<DioException>().having(
          (e) => e.error.toString(), 'error', isNot(contains('NetworkGate')))),
    );
  });
}
