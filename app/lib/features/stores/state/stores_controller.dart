import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/location/location_service.dart';
import '../../../core/sync/refresh_outcome.dart';
import 'stores_providers.dart';

/// UI state of the stores list: search text and the last known location.
class StoresListState {
  const StoresListState({
    this.query = '',
    this.location,
    this.locating = false,
    this.cardDismissed = false,
  });

  final String query;

  /// Null until the first (silent) location check completes.
  final LocationResult? location;
  final bool locating;
  final bool cardDismissed;

  StoresListState copyWith({
    String? query,
    LocationResult? location,
    bool? locating,
    bool? cardDismissed,
  }) =>
      StoresListState(
        query: query ?? this.query,
        location: location ?? this.location,
        locating: locating ?? this.locating,
        cardDismissed: cardDismissed ?? this.cardDismissed,
      );
}

class StoresListController extends Notifier<StoresListState> {
  var _disposed = false;

  @override
  StoresListState build() {
    ref.onDispose(() => _disposed = true);
    return const StoresListState();
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  void dismissCard() => state = state.copyWith(cardDismissed: true);

  /// Silent check when the screen opens; [prompt] only from a user action.
  Future<void> locate({bool prompt = false}) async {
    if (state.locating) return;
    state = state.copyWith(locating: true);
    LocationResult result;
    try {
      result = await ref.read(locationServiceProvider).current(prompt: prompt);
    } on Object {
      result = const Unavailable();
    }
    if (_disposed) return;
    state = state.copyWith(location: result, locating: false);
  }

  Future<void> openSettings() =>
      ref.read(locationServiceProvider).openSettings();
}

final storesListControllerProvider =
    NotifierProvider<StoresListController, StoresListState>(
  StoresListController.new,
);

/// Drives `StoresRepository.refresh`.
class StoresRefreshState extends Notifier<RefreshStatus> {
  var _disposed = false;

  @override
  RefreshStatus build() {
    ref.onDispose(() => _disposed = true);
    return const RefreshIdle();
  }

  Future<RefreshOutcome> refresh({bool force = false}) async {
    state = const RefreshLoading();
    RefreshOutcome outcome;
    try {
      outcome = await ref.read(storesRepositoryProvider).refresh(force: force);
    } on Object catch (e) {
      outcome = Failed(e is AppError ? e : UnknownError(e));
    }
    if (!_disposed) state = statusOf(outcome);
    return outcome;
  }
}

final storesRefreshProvider =
    NotifierProvider<StoresRefreshState, RefreshStatus>(
  StoresRefreshState.new,
);
