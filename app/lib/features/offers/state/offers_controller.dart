import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../data/offers_repository.dart';
import 'offers_providers.dart';

/// Category and text filter applied locally to the cached offers.
class OffersFilter {
  const OffersFilter({this.categorySlug, this.query = ''});

  final String? categorySlug;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is OffersFilter &&
      other.categorySlug == categorySlug &&
      other.query == query;

  @override
  int get hashCode => Object.hash(categorySlug, query);
}

class OffersFilterNotifier extends Notifier<OffersFilter> {
  @override
  OffersFilter build() => const OffersFilter();

  void setCategory(String? slug) =>
      state = OffersFilter(categorySlug: slug, query: state.query);

  void setQuery(String query) =>
      state = OffersFilter(categorySlug: state.categorySlug, query: query);
}

final offersFilterProvider =
    NotifierProvider<OffersFilterNotifier, OffersFilter>(
  OffersFilterNotifier.new,
);

/// Progress of the last refresh, for the UI.
sealed class RefreshStatus {
  const RefreshStatus();
}

final class RefreshIdle extends RefreshStatus {
  const RefreshIdle();
}

final class RefreshLoading extends RefreshStatus {
  const RefreshLoading();
}

final class RefreshFailed extends RefreshStatus {
  const RefreshFailed(this.error);
  final AppError error;
}

RefreshStatus _statusOf(RefreshOutcome outcome) => switch (outcome) {
      Failed(:final error) => RefreshFailed(error),
      Refreshed() || SkippedFresh() => const RefreshIdle(),
    };

abstract class _RefreshNotifier extends Notifier<RefreshStatus> {
  var _disposed = false;

  @override
  RefreshStatus build() {
    ref.onDispose(() => _disposed = true);
    return const RefreshIdle();
  }

  Future<RefreshOutcome> run(Future<RefreshOutcome> Function() action) async {
    state = const RefreshLoading();
    RefreshOutcome outcome;
    try {
      outcome = await action();
    } on Object catch (e) {
      // The repository never throws; this guards provider wiring errors.
      outcome = Failed(e is AppError ? e : UnknownError(e));
    }
    if (!_disposed) state = _statusOf(outcome);
    return outcome;
  }
}

/// Drives `refreshCurrentFlyer`: called on first build (TTL applies) and on
/// pull-to-refresh (`force: true`).
class OffersRefreshState extends _RefreshNotifier {
  Future<RefreshOutcome> refresh({bool force = false}) => run(
        () => ref
            .read(offersRepositoryProvider)
            .refreshCurrentFlyer(force: force),
      );
}

final offersRefreshProvider =
    NotifierProvider<OffersRefreshState, RefreshStatus>(
  OffersRefreshState.new,
);

/// Drives `refreshArchive`.
class ArchiveRefreshState extends _RefreshNotifier {
  Future<RefreshOutcome> refresh() =>
      run(() => ref.read(offersRepositoryProvider).refreshArchive());
}

final archiveRefreshProvider =
    NotifierProvider<ArchiveRefreshState, RefreshStatus>(
  ArchiveRefreshState.new,
);
