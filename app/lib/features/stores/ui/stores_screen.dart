import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/location/location_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/sync/refresh_outcome.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../../../core/ui/offline_banner.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/util/clock.dart';
import '../state/stores_controller.dart';
import '../state/stores_providers.dart';
import 'store_tile.dart';

/// Stores tab: searchable list, nearest first when the location is known.
class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _search = TextEditingController();
  var _firstRefreshDone = false;
  RefreshFailed? _dismissed;

  /// Last emitted list: a new search restarts the stream, and the list must
  /// not flash a skeleton in between.
  List<StoreListItem>? _lastItems;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      if (!mounted) return;
      // Silent check: never shows a permission dialog.
      ref.read(storesListControllerProvider.notifier).locate();
      await ref.read(storesRefreshProvider.notifier).refresh();
      if (mounted) setState(() => _firstRefreshDone = true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    setState(() {});
    ref.read(storesListControllerProvider.notifier).setQuery(text);
  }

  void _clearQuery() {
    _search.clear();
    _onQuery('');
  }

  Future<void> _refresh() =>
      ref.read(storesRefreshProvider.notifier).refresh(force: true);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sorted = ref.watch(storesSortedProvider);
    final status = ref.watch(storesRefreshProvider);
    final query = ref.watch(
      storesListControllerProvider.select((s) => s.query),
    );
    final items = sorted.valueOrNull ?? _lastItems;
    _lastItems = items;
    final hasCache = items != null && items.isNotEmpty;
    final searching = query.trim().isNotEmpty;

    final List<Widget> slivers;
    if (sorted.hasError && items == null) {
      slivers = [
        _fill(ErrorView(error: UnknownError(sorted.error!), onRetry: _refresh))
      ];
    } else if (!hasCache && !searching) {
      if (items == null ||
          status is RefreshLoading ||
          (!_firstRefreshDone && status is RefreshIdle)) {
        slivers = [_skeletons()];
      } else if (status is RefreshFailed) {
        slivers = [_fill(ErrorView(error: status.error, onRetry: _refresh))];
      } else {
        slivers = [
          _fill(
            EmptyState(
              icon: Icons.storefront_outlined,
              title: l.storesEmptyTitle,
              message: l.storesEmptyMessage,
            ),
          ),
        ];
      }
    } else {
      final now = ref.watch(clockProvider)();
      slivers = [
        SliverToBoxAdapter(child: _statusBanner(status)),
        SliverToBoxAdapter(child: _locationCard(l)),
        SliverToBoxAdapter(child: _searchField(l)),
        if (items!.isEmpty)
          _fill(
            EmptyState(
              icon: Icons.search_off,
              title: l.storesNoMatchTitle,
              message: l.storesNoMatchMessage,
            ),
          )
        else
          SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => StoreTile(
              key: ValueKey(items[i].store.id),
              item: items[i],
              now: now,
              onTap: () => context.push(Routes.storeDetail(items[i].store.id)),
            ),
          ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.tabStores)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }

  Widget _fill(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: child);

  Widget _skeletons() => SliverList.builder(
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Skeleton(height: 56),
        ),
      );

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

  Widget _locationCard(AppLocalizations l) {
    final s = ref.watch(storesListControllerProvider);
    final location = s.location;
    if (location == null || location is Granted || s.cardDismissed) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(storesListControllerProvider.notifier);
    final needsSettings = location is ServiceDisabled ||
        (location is Denied && location.permanent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(Icons.my_location),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l.storesLocationTitle),
                    ),
                  ),
                  IconButton(
                    tooltip: l.storesLocationDismiss,
                    icon: const Icon(Icons.close),
                    onPressed: controller.dismissCard,
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: s.locating
                    ? null
                    : needsSettings
                        ? controller.openSettings
                        : () => controller.locate(prompt: true),
                child: Text(
                  needsSettings
                      ? l.storesLocationSettings
                      : l.storesLocationAllow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _search,
          onChanged: _onQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.storesSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l.storesSearchClear,
                    icon: const Icon(Icons.clear),
                    onPressed: _clearQuery,
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
