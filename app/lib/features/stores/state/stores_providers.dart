import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/location/location_service.dart';
import '../../../core/util/clock.dart';
import '../../../core/util/search_fold.dart';
import '../../../core/util/store_utils.dart';
import '../data/stores_repository.dart';
import 'stores_controller.dart';

final storesRepositoryProvider = Provider<StoresRepository>((ref) {
  return StoresRepository(
    storesApi: ref.watch(apiClientProvider).getStoresApi(),
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Cached stores matching the search text (accent-insensitive).
final storesProvider = StreamProvider<List<StoreRow>>((ref) {
  final query = ref.watch(storesListControllerProvider.select((s) => s.query));
  return ref.watch(storesRepositoryProvider).watchStores(query: query);
});

final allHoursProvider = StreamProvider<List<OpeningHoursRow>>(
  (ref) => ref.watch(storesRepositoryProvider).watchAllHours(),
);

/// One cached store with its hours (null when not cached).
final storeDetailProvider =
    StreamProvider.autoDispose.family<StoreWithHours?, int>(
  (ref, id) => ref.watch(storesRepositoryProvider).watchStore(id),
);

/// A store as shown in the list.
class StoreListItem {
  const StoreListItem({
    required this.store,
    required this.hours,
    required this.distanceKm,
  });

  final StoreRow store;
  final List<OpeningHoursRow> hours;

  /// Null when the location is unknown.
  final double? distanceKm;
}

/// Stores sorted by distance (location granted) or by name (accent- and
/// case-insensitive) otherwise.
final storesSortedProvider = Provider<AsyncValue<List<StoreListItem>>>((ref) {
  final stores = ref.watch(storesProvider);
  final hours = ref.watch(allHoursProvider).valueOrNull ?? const [];
  final location = ref.watch(
    storesListControllerProvider.select((s) => s.location),
  );
  return stores.whenData((rows) => sortStores(rows, hours, location));
});

List<StoreListItem> sortStores(
  List<StoreRow> rows,
  List<OpeningHoursRow> hours,
  LocationResult? location,
) {
  final byStore = <int, List<OpeningHoursRow>>{};
  for (final h in hours) {
    (byStore[h.storeId] ??= []).add(h);
  }
  final items = [
    for (final s in rows)
      StoreListItem(
        store: s,
        hours: byStore[s.id] ?? const [],
        distanceKm: location is Granted
            ? distanceKm(location.lat, location.lng, s.latitude, s.longitude)
            : null,
      ),
  ];
  int byName(StoreListItem a, StoreListItem b) {
    final c = foldSearch(a.store.name).compareTo(foldSearch(b.store.name));
    return c != 0 ? c : a.store.id.compareTo(b.store.id);
  }

  items.sort(
    location is Granted
        ? (a, b) {
            final c = a.distanceKm!.compareTo(b.distanceKm!);
            return c != 0 ? c : byName(a, b);
          }
        : byName,
  );
  return items;
}
