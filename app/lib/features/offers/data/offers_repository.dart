import 'package:api_client/api_client.dart' as api;
import 'package:dio/dio.dart';

import '../../../core/api/paging.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/public_dao.dart';
import '../../../core/db/daos/sync_meta_keys.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/util/clock.dart';

/// Result of a refresh attempt; refreshes never throw.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// New data was fetched and stored (or the server has no current flyer).
final class Refreshed extends RefreshOutcome {
  const Refreshed();
}

/// The cache is younger than the TTL; no request was made.
final class SkippedFresh extends RefreshOutcome {
  const SkippedFresh();
}

/// The refresh failed; the cache is untouched.
final class Failed extends RefreshOutcome {
  const Failed(this.error);
  final AppError error;
}

const currentFlyerTtl = Duration(minutes: 15);
const _maxPages = 50;

/// Public data (weekly flyer, categories, archive) with a local cache.
///
/// The flyer returned by the server IS the current flyer. This class never
/// compares flyer dates with the device clock; the clock only drives the
/// refresh TTL.
class OffersRepository {
  OffersRepository({
    required api.FlyersApi flyersApi,
    required api.CategoriesApi categoriesApi,
    required AppDatabase db,
    required Clock clock,
  })  : _flyers = flyersApi,
        _categories = categoriesApi,
        _db = db,
        _clock = clock;

  final api.FlyersApi _flyers;
  final api.CategoriesApi _categories;
  final AppDatabase _db;
  final Clock _clock;

  Future<RefreshOutcome>? _inFlight;

  PublicDao get _dao => _db.publicDao;

  Stream<FlyerRow?> watchCurrentFlyer() => _dao.watchCurrentFlyer();

  Stream<List<OfferWithProduct>> watchOffers({
    String? categorySlug,
    String query = '',
  }) =>
      _dao.watchCurrentOffers(categorySlug: categorySlug, query: query);

  Stream<List<CategoryRow>> watchCategories() => _dao.watchCategories();

  Stream<List<FlyerRow>> watchArchive() => _dao.watchArchive();

  /// Refreshes the current flyer, its offers and the categories. Concurrent
  /// calls share one in-flight request (a forced call joins a running one).
  Future<RefreshOutcome> refreshCurrentFlyer({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final future = _refreshCurrent(force).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<RefreshOutcome> _refreshCurrent(bool force) async {
    try {
      if (!force && await _isFresh()) return const SkippedFresh();

      final api.FlyerDetail detail;
      try {
        detail = (await _flyers.flyersCurrentRetrieve()).data!;
      } on DioException catch (e) {
        final error = mapDioException(e);
        if (error is ApiError && error.code == 'not_found') {
          await _dao.clearCurrentFlyer();
          await _db.syncMetaDao.remove(currentFlyerFetchedAt);
          return const Refreshed();
        }
        return Failed(error);
      }

      final categories = await _fetchCategories();

      // Everything is mapped and fetched before the first write, and the
      // write is one transaction: any failure leaves the cache untouched.
      final flyerRow = mapFlyerDetail(detail);
      final productRows = mapProducts(detail);
      final offerRows = mapOffers(detail);
      await _db.transaction(() async {
        await _dao.upsertCategories(categories);
        await _dao.replaceCurrentFlyer(flyerRow, productRows, offerRows);
      });
      await _db.syncMetaDao.set(
        currentFlyerFetchedAt,
        _clock().toUtc().toIso8601String(),
      );
      return const Refreshed();
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }

  Future<bool> _isFresh() async {
    final raw = await _db.syncMetaDao.get(currentFlyerFetchedAt);
    final fetchedAt = raw == null ? null : DateTime.tryParse(raw);
    if (fetchedAt == null) return false;
    final age = _clock().difference(fetchedAt);
    // A negative age means the device clock moved back: treat as stale.
    return !age.isNegative && age < currentFlyerTtl;
  }

  Future<List<CategoryRow>> _fetchCategories() async {
    final all = await fetchAllPages<api.Category>(
      (cursor) async {
        final page = (await _categories.categoriesList(cursor: cursor)).data!;
        return toPageResult(page.results, page.next);
      },
      maxPages: _maxPages,
    );
    return mapCategories(all);
  }

  /// Refreshes the flyer archive. Never changes which flyer is current.
  Future<RefreshOutcome> refreshArchive() async {
    try {
      final all = await fetchAllPages<api.FlyerList>(
        (cursor) async {
          final page = (await _flyers.flyersList(cursor: cursor)).data!;
          return toPageResult(page.results, page.next);
        },
        maxPages: _maxPages,
      );
      await _dao.upsertArchiveFlyers([
        for (final f in all)
          FlyerRow(
            id: f.id,
            title: f.title,
            validFrom: isoDate(f.validFrom),
            validTo: isoDate(f.validTo),
            coverImageUrl: f.coverImage,
            offerCount: f.offerCount,
            isCurrent: false,
          ),
      ]);
      return const Refreshed();
    } on DioException catch (e) {
      return Failed(mapDioException(e));
    } on Object catch (e) {
      return Failed(UnknownError(e));
    }
  }
}

// ---------------------------------------------------------------- mapping

/// `YYYY-MM-DD` of the calendar day carried by a parsed API date.
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

FlyerRow mapFlyerDetail(api.FlyerDetail d) => FlyerRow(
      id: d.id,
      title: d.title,
      validFrom: isoDate(d.validFrom),
      validTo: isoDate(d.validTo),
      coverImageUrl: d.coverImage,
      offerCount: d.offers.length,
      isCurrent: true,
    );

/// One row per distinct product (a product may appear in several offers).
List<ProductRow> mapProducts(api.FlyerDetail d) {
  final byId = <int, ProductRow>{};
  for (final o in d.offers) {
    final p = o.product;
    byId[p.id] = ProductRow(
      id: p.id,
      name: p.name,
      description: p.description ?? '',
      unit: p.unit ?? '',
      imageUrl: p.image,
      categoryId: p.category.id,
    );
  }
  return byId.values.toList();
}

List<OfferRow> mapOffers(api.FlyerDetail d) => [
      for (var i = 0; i < d.offers.length; i++)
        OfferRow(
          id: d.offers[i].id,
          flyerId: d.id,
          productId: d.offers[i].product.id,
          price: d.offers[i].price,
          oldPrice: d.offers[i].oldPrice,
          badgeText: d.offers[i].badgeText ?? '',
          sortOrder: i,
          validFrom: d.offers[i].validFrom == null
              ? null
              : isoDate(d.offers[i].validFrom!),
          validTo: d.offers[i].validTo == null
              ? null
              : isoDate(d.offers[i].validTo!),
        ),
    ];

/// The API gives no sort order for categories: keep the server's order.
List<CategoryRow> mapCategories(List<api.Category> list) => [
      for (var i = 0; i < list.length; i++)
        CategoryRow(
          id: list[i].id,
          name: list[i].name,
          slug: list[i].slug,
          sortOrder: i,
        ),
    ];
