import '../errors/app_error.dart';

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

RefreshStatus statusOf(RefreshOutcome outcome) => switch (outcome) {
      Failed(:final error) => RefreshFailed(error),
      Refreshed() || SkippedFresh() => const RefreshIdle(),
    };
