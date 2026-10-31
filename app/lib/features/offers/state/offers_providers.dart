import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/util/clock.dart';
import '../data/offers_repository.dart';
import 'offers_controller.dart';

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return OffersRepository(
    flyersApi: client.getFlyersApi(),
    categoriesApi: client.getCategoriesApi(),
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

/// The cached current flyer (null when there is none).
final currentFlyerProvider = StreamProvider<FlyerRow?>(
  (ref) => ref.watch(offersRepositoryProvider).watchCurrentFlyer(),
);

final categoriesProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref.watch(offersRepositoryProvider).watchCategories(),
);

/// Offers of the current flyer, filtered locally by [offersFilterProvider].
final offersProvider = StreamProvider<List<OfferWithProduct>>((ref) {
  final filter = ref.watch(offersFilterProvider);
  return ref
      .watch(offersRepositoryProvider)
      .watchOffers(categorySlug: filter.categorySlug, query: filter.query);
});

final archiveProvider = StreamProvider<List<FlyerRow>>(
  (ref) => ref.watch(offersRepositoryProvider).watchArchive(),
);
