import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/date_format_fr.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../../../core/ui/offline_banner.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/util/clock.dart';
import '../../../core/sync/refresh_outcome.dart';
import '../state/offers_controller.dart';
import '../state/offers_providers.dart';
import 'offer_card.dart';
import 'offer_detail_sheet.dart';

/// Offers tab: the current flyer, searchable and filterable by category.
class OffersHomeScreen extends ConsumerStatefulWidget {
  const OffersHomeScreen({super.key});

  @override
  ConsumerState<OffersHomeScreen> createState() => _OffersHomeScreenState();
}

class _OffersHomeScreenState extends ConsumerState<OffersHomeScreen> {
  static const _debounce = Duration(milliseconds: 300);
  static const _maxCardExtent = 220.0;
  static const _gridSpacing = 12.0;

  final _search = TextEditingController();
  Timer? _timer;
  RefreshFailed? _dismissed;

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      if (mounted) ref.read(offersRefreshProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    setState(() {});
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) ref.read(offersFilterProvider.notifier).setQuery(text);
    });
  }

  void _clearQuery() {
    _timer?.cancel();
    _search.clear();
    setState(() {});
    ref.read(offersFilterProvider.notifier).setQuery('');
  }

  Future<void> _pull() =>
      ref.read(offersRefreshProvider.notifier).refresh(force: true);

  void _retry() =>
      ref.read(offersRefreshProvider.notifier).refresh(force: true);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final flyerAsync = ref.watch(currentFlyerProvider);
    final status = ref.watch(offersRefreshProvider);
    final flyer = flyerAsync.valueOrNull;

    final List<Widget> slivers;
    if (flyerAsync.hasError && flyer == null) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            error: UnknownError(flyerAsync.error!),
            onRetry: _retry,
          ),
        ),
      ];
    } else if (flyer == null) {
      slivers = switch ((flyerAsync.isLoading, status)) {
        (true, _) || (_, RefreshLoading()) => [_skeletonGrid()],
        (_, RefreshFailed(:final error)) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(error: error, onRetry: _retry),
            ),
          ],
        _ => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.local_offer_outlined,
                title: l.offersNoFlyerTitle,
                message: l.offersNoFlyerMessage,
              ),
            ),
          ],
      };
    } else {
      slivers = [
        SliverToBoxAdapter(child: _statusBanner(status)),
        SliverToBoxAdapter(child: _header(flyer)),
        SliverToBoxAdapter(child: _searchField(l)),
        SliverToBoxAdapter(child: _chips(l)),
        ..._offerSlivers(l),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.appName)),
      body: RefreshIndicator(
        onRefresh: _pull,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }

  Widget _statusBanner(RefreshStatus status) {
    if (status is! RefreshFailed) return const SizedBox.shrink();
    final error = status.error;
    if (error is NetworkError || error is AppTimeoutError) {
      return const OfflineBanner();
    }
    if (identical(_dismissed, status)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return MaterialBanner(
      content: Text(userMessage(error, l)),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = status),
          child: Text(l.actionClose),
        ),
      ],
    );
  }

  Widget _header(FlyerRow flyer) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String? dates;
    try {
      dates = formatDateRangeFr(flyer.validFrom, flyer.validTo);
    } on FormatException {
      dates = null;
    }
    final maybeEnded = isPastFr(flyer.validTo, ref.watch(clockProvider)());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(flyer.title, style: theme.textTheme.titleLarge),
              if (dates != null) ...[
                const SizedBox(height: 4),
                Text(
                  l.offersValidity(dates),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (maybeEnded) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.offersMaybeEnded,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.push(Routes.flyerArchive),
                icon: const Icon(Icons.history),
                label: Text(l.offersArchiveAction),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          controller: _search,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.offersSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l.offersSearchClear,
                    icon: const Icon(Icons.clear),
                    onPressed: _clearQuery,
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _chips(AppLocalizations l) {
    final filter = ref.watch(offersFilterProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryRow>[];
    final notifier = ref.read(offersFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(l.offersCategoryAll),
              selected: filter.categorySlug == null,
              onSelected: (_) => notifier.setCategory(null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: filter.categorySlug == c.slug,
                onSelected: (_) => notifier.setCategory(c.slug),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _offerSlivers(AppLocalizations l) {
    final offers = ref.watch(offersProvider);
    return offers.when(
      loading: () => [_skeletonGrid()],
      error: (e, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(error: UnknownError(e), onRetry: _retry),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off,
                title: l.offersNoMatchTitle,
                message: l.offersNoMatchMessage,
              ),
            ),
          ];
        }
        return [
          _grid(
            items.length,
            (context, i) => OfferCard(
              item: items[i],
              onTap: () => OfferDetailSheet.show(context, items[i]),
            ),
          ),
        ];
      },
    );
  }

  Widget _skeletonGrid() => _grid(
        6,
        (context, i) =>
            const Skeleton(radius: BorderRadius.all(Radius.circular(12))),
      );

  /// Responsive grid: 2 columns on phones, more on wide screens. The columns
  /// get wider as the text scale grows so cards never overflow.
  Widget _grid(int count, NullableIndexedWidgetBuilder builder) {
    final scaler = MediaQuery.textScalerOf(context);
    final maxExtent = _maxCardExtent * scaler.scale(1).clamp(1.0, 3.0);
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns =
              (width / (maxExtent + _gridSpacing)).ceil().clamp(1, 12);
          final cardWidth = (width - _gridSpacing * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              mainAxisSpacing: _gridSpacing,
              crossAxisSpacing: _gridSpacing,
              mainAxisExtent: OfferCard.heightFor(cardWidth, scaler),
            ),
            delegate: SliverChildBuilderDelegate(builder, childCount: count),
          );
        },
      ),
    );
  }
}
