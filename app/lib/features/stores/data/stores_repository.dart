import 'dart:async';

import 'package:api_client/api_client.dart' as api;
import 'package:dio/dio.dart';

import '../../../core/api/paging.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/stores_dao.dart';
import '../../../core/db/daos/sync_meta_keys.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/sync/refresh_outcome.dart';
import '../../../core/util/clock.dart';

const storesTtl = Duration(hours: 24);
const _maxPages = 50;
const _detailConcurrency = 4;

/// Stores and their opening hours, cached locally.
///
/// The list endpoint carries no opening hours: they come from one detail
/// request per store. The list is fetched WITHOUT coordinates (distances are
/// computed on the device, so the cache does not depend on the user's
/// position and the location is never sent to the server).
class StoresRepository {
  StoresRepository({
    required api.StoresApi storesApi,
    required AppDatabase db,
    required Clock clock,
  })  : _api = storesApi,
        _db = db,
        _clock = clock;

  final api.StoresApi _api;
  final AppDatabase _db;
  final Clock _clock;

  Future<RefreshOutcome>? _inFlight;

  StoresDao get _dao => _db.storesDao;

  Stream<List<StoreRow>> watchStores({String query = ''}) =>
      _dao.watchStores(query: query);

  Stream<List<OpeningHoursRow>> watchAllHours() => _dao.watchAllHours();

  Stream<StoreWithHours?> watchStore(int id) => _dao.watchStore(id);

  /// Concurrent calls share one in-flight request.
  Future<RefreshOutcome> refresh({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _refresh(force).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<RefreshOutcome> _refresh(bool force) async {
    try {
      if (!force && await _isFresh()) return const SkippedFresh();

      final list = await fetchAllPages<api.Store>(
        (cursor) async {
          final page = (await _api.storesList(cursor: cursor)).data!;
          return toPageResult(page.results, page.next);
        },
        maxPages: _maxPages,
      );
      final storeRows = [
        for (final s in list)
          if (_mapStore(s.id, s) case final row?) row,
      ];
      final hourRows = await _fetchHours([for (final r in storeRows) r.id]);

      await _dao.replaceStores(storeRows, hourRows);
      await _db.syncMetaDao.set(
        storesFetchedAt,
        _clock().toUtc().toIso8601String(),
      );
      return const Refreshed();
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }

  /// Detail requests, [_detailConcurrency] at a time. A failed detail only
  /// means that store has no hours yet.
  Future<List<OpeningHoursRow>> _fetchHours(List<int> ids) async {
    final out = <OpeningHoursRow>[];
    final queue = List.of(ids);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        try {
          final d = (await _api.storesRetrieve(id: id)).data!;
          out.addAll(_mapHours(id, d.openingHours));
        } on Object {
          // Ignored on purpose; see above.
        }
      }
    }

    await Future.wait([for (var i = 0; i < _detailConcurrency; i++) worker()]);
    return out;
  }

  /// Fetches one store's detail and replaces that store's hours (and row).
  /// Never throws.
  Future<RefreshOutcome> refreshStore(int id) async {
    try {
      final d = (await _api.storesRetrieve(id: id)).data!;
      final row = _mapStore(d.id, d);
      if (row == null) return Failed(UnknownError(StateError('bad store')));
      await _dao.upsertStoreWithHours(row, _mapHours(d.id, d.openingHours));
      return const Refreshed();
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }

  Future<bool> _isFresh() async {
    final raw = await _db.syncMetaDao.get(storesFetchedAt);
    final fetchedAt = raw == null ? null : DateTime.tryParse(raw);
    if (fetchedAt == null) return false;
    final age = _clock().difference(fetchedAt);
    // A negative age means the device clock moved back: treat as stale.
    return !age.isNegative && age < storesTtl;
  }
}

/// [s] is an `api.Store` or an `api.StoreDetail` (same fields); a store with
/// unreadable coordinates is dropped.
StoreRow? _mapStore(int id, Object s) {
  final (name, address, city, postcode, lat, lng, phone) = switch (s) {
    api.Store() => (
        s.name,
        s.address,
        s.city,
        s.postcode,
        s.latitude,
        s.longitude,
        s.phone
      ),
    api.StoreDetail() => (
        s.name,
        s.address,
        s.city,
        s.postcode,
        s.latitude,
        s.longitude,
        s.phone
      ),
    _ => throw ArgumentError.value(s),
  };
  final la = double.tryParse(lat);
  final ln = double.tryParse(lng);
  if (la == null || ln == null) return null;
  return StoreRow(
    id: id,
    name: name,
    address: address,
    city: city,
    postcode: postcode,
    latitude: la,
    longitude: ln,
    phone: phone ?? '',
  );
}

List<OpeningHoursRow> _mapHours(int storeId, List<api.OpeningHours> hours) {
  final byDay = <int, OpeningHoursRow>{};
  for (final h in hours) {
    byDay[h.weekday] = OpeningHoursRow(
      storeId: storeId,
      weekday: h.weekday,
      opens: h.opens,
      closes: h.closes,
    );
  }
  return byDay.values.toList();
}
