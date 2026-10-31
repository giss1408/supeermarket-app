import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/ui/date_format_fr.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../../../core/ui/offline_banner.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/util/clock.dart';
import '../state/offers_controller.dart';
import '../state/offers_providers.dart';

/// Past and upcoming flyers. Items are not tappable in v1 (no flyer-detail
/// route yet).
class FlyerArchiveScreen extends ConsumerStatefulWidget {
  const FlyerArchiveScreen({super.key});

  @override
  ConsumerState<FlyerArchiveScreen> createState() => _FlyerArchiveScreenState();
}

class _FlyerArchiveScreenState extends ConsumerState<FlyerArchiveScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>(() {
      if (mounted) ref.read(archiveRefreshProvider.notifier).refresh();
    });
  }

  Future<void> _refresh() =>
      ref.read(archiveRefreshProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final archive = ref.watch(archiveProvider);
    final status = ref.watch(archiveRefreshProvider);
    final flyers = archive.valueOrNull;

    final List<Widget> slivers;
    if (flyers == null) {
      slivers = [
        if (archive.hasError)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              error: UnknownError(archive.error!),
              onRetry: _refresh,
            ),
          )
        else if (status is RefreshFailed)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(error: status.error, onRetry: _refresh),
          )
        else
          SliverList.list(
            children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Skeleton(
                    height: 88,
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
            ],
          ),
      ];
    } else if (flyers.isEmpty) {
      slivers = [
        SliverToBoxAdapter(child: _banner(status)),
        switch (status) {
          RefreshLoading() => SliverList.list(
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Skeleton(
                    height: 88,
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ],
            ),
          RefreshFailed(:final error) when !_isOffline(error) =>
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(error: error, onRetry: _refresh),
            ),
          _ => SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.history,
                title: l.archiveEmptyTitle,
                message: l.archiveEmptyMessage,
              ),
            ),
        },
      ];
    } else {
      final now = ref.watch(clockProvider)();
      slivers = [
        SliverToBoxAdapter(child: _banner(status)),
        SliverList.builder(
          itemCount: flyers.length,
          itemBuilder: (context, i) => _FlyerTile(flyer: flyers[i], now: now),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.archiveTitle)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }

  static bool _isOffline(AppError e) =>
      e is NetworkError || e is AppTimeoutError;

  Widget _banner(RefreshStatus status) =>
      status is RefreshFailed && _isOffline(status.error)
          ? const OfflineBanner()
          : const SizedBox.shrink();
}

enum _Tag { ended, upcoming, current }

class _FlyerTile extends StatelessWidget {
  const _FlyerTile({required this.flyer, required this.now});

  final FlyerRow flyer;
  final DateTime now;

  /// Display hint from the device date; never decides what is current.
  _Tag get _tag => isPastFr(flyer.validTo, now)
      ? _Tag.ended
      : isFutureFr(flyer.validFrom, now)
          ? _Tag.upcoming
          : _Tag.current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String? dates;
    try {
      dates = formatDateRangeFr(flyer.validFrom, flyer.validTo);
    } on FormatException {
      dates = null;
    }
    final tag = _tag;
    final tagText = switch (tag) {
      _Tag.ended => l.archiveTagEnded,
      _Tag.upcoming => l.archiveTagUpcoming,
      _Tag.current => l.archiveTagCurrent,
    };
    final (tagBg, tagFg) = switch (tag) {
      _Tag.ended => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _Tag.upcoming => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _Tag.current => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    final count = l.archiveOfferCount(flyer.offerCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Semantics(
        container: true,
        label:
            [flyer.title, if (dates != null) dates, count, tagText].join(', '),
        excludeSemantics: true,
        child: Card(
          margin: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(flyer.title, style: theme.textTheme.titleMedium),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            tagText,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: tagFg),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (dates != null) Text(dates),
                  Text(
                    count,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
