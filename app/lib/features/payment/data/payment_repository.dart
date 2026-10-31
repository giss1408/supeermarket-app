import 'package:dio/dio.dart';

import '../../../core/api/paging.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/sync_meta_keys.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/ui/payment_provider.dart';
import '../../../core/util/clock.dart';

const _maxPages = 50;
const _path = '/api/v1/payment-methods';

/// Outcome of a payment-numbers refresh; refreshes never throw.
sealed class PaymentRefreshResult {
  const PaymentRefreshResult();
}

/// The server's list was fetched and stored; [at] is the device time.
final class Refreshed extends PaymentRefreshResult {
  const Refreshed(this.at);
  final DateTime at;
}

/// The refresh failed; cached numbers and last-checked time are untouched.
final class Failed extends PaymentRefreshResult {
  const Failed(this.error);
  final AppError error;
}

/// Mobile-money numbers. A stale number sends a customer's money to the wrong
/// place, so [refresh] has NO TTL: every call goes to the network.
///
/// The request goes through the app's Dio on the generated client's path
/// instead of `PaymentMethodsApi`: the generated client rejects the whole
/// page when ONE item has an unknown provider, while an unknown provider must
/// only be skipped.
class PaymentRepository {
  PaymentRepository({
    required Dio dio,
    required AppDatabase db,
    required Clock clock,
  })  : _dio = dio,
        _db = db,
        _clock = clock;

  final Dio _dio;
  final AppDatabase _db;
  final Clock _clock;

  Future<PaymentRefreshResult>? _inFlight;

  Stream<List<PaymentMethodRow>> watchMethods() =>
      _db.paymentDao.watchMethods();

  /// Time of the last SUCCESSFUL refresh; null when never or unparsable.
  Stream<DateTime?> watchLastChecked() => _db.syncMetaDao
      .watch(paymentLastChecked)
      .map((raw) => raw == null ? null : DateTime.tryParse(raw));

  /// Always fetches. Concurrent calls share one in-flight request.
  Future<PaymentRefreshResult> refresh() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _refresh().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<PaymentRefreshResult> _refresh() async {
    try {
      final items = await fetchAllPages<Map<String, dynamic>>(
        (cursor) async {
          final res = await _dio.get<Object>(
            _path,
            queryParameters: {if (cursor != null) 'cursor': cursor},
          );
          final body = res.data;
          if (body is! Map<String, dynamic>) {
            throw FormatException('Unexpected payment-methods body', body);
          }
          final results =
              (body['results'] as List).cast<Map<String, dynamic>>();
          return toPageResult(results, body['next'] as String?);
        },
        maxPages: _maxPages,
      );
      final rows = <PaymentMethodRow>[];
      for (final item in items) {
        final row = _toRow(item);
        if (row != null) rows.add(row);
      }
      await _db.paymentDao.replaceMethods(rows);
      final at = _clock();
      await _db.syncMetaDao
          .set(paymentLastChecked, at.toUtc().toIso8601String());
      return Refreshed(at);
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }

  /// Null (skip) when the provider is not one of the three known ones.
  PaymentMethodRow? _toRow(Map<String, dynamic> item) {
    final String provider;
    try {
      provider = PaymentProvider.fromApi(item['provider'] as String).apiValue;
    } on Object {
      return null;
    }
    return PaymentMethodRow(
      provider: provider,
      phoneNumber: item['phone_number'] as String,
      displayName: (item['display_name'] as String?) ?? '',
      instructions: (item['instructions'] as String?) ?? '',
      updatedAt: item['updated_at'] as String,
    );
  }
}
