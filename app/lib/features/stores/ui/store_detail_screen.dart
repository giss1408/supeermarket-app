import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/util/clock.dart';
import '../../../core/util/store_utils.dart';
import '../../../core/util/url_opener.dart';
import '../state/stores_providers.dart';
import 'store_tile.dart';
import 'weekday_names.dart';
import '../../../core/theme/tokens.dart';

/// One store: address, call, directions, the week's opening hours.
class StoreDetailScreen extends ConsumerStatefulWidget {
  const StoreDetailScreen({super.key, required this.storeId});

  final int storeId;

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  var _checked = false;

  @override
  void initState() {
    super.initState();
    Future<void>(_ensureHours);
  }

  /// Fetches the detail once when the cache has no such store or no hours.
  Future<void> _ensureHours() async {
    if (!mounted) return;
    try {
      final repo = ref.read(storesRepositoryProvider);
      final cached = await ref.read(storeDetailProvider(widget.storeId).future);
      if (cached == null || cached.hours.isEmpty) {
        await repo.refreshStore(widget.storeId);
      }
    } on Object {
      // Offline or misconfigured: the cache (or "not found") is shown.
    }
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _open(Uri uri, {bool maps = false}) async {
    final ok = await ref.read(urlOpenerProvider).open(uri);
    if (!ok && maps && mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.storeMapsError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(storeDetailProvider(widget.storeId)).valueOrNull;
    final Widget body;
    if (data != null) {
      body = _content(l, data);
    } else if (!_checked) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 28),
            SizedBox(height: 12),
            Skeleton(height: 56),
          ],
        ),
      );
    } else {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: l.storeNotFoundTitle,
        message: l.storeNotFoundMessage,
        actionLabel: l.storeBack,
        onAction: () =>
            context.canPop() ? context.pop() : context.go(Routes.stores),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(data?.store.name ?? l.tabStores)),
      body: body,
    );
  }

  Widget _content(AppLocalizations l, StoreWithHours data) {
    final theme = Theme.of(context);
    final s = data.store;
    final now = ref.watch(clockProvider)();
    final hasHours = data.hours.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(s.address, style: theme.textTheme.bodyLarge),
        Text(
          '${s.postcode} ${s.city}'.trim(),
          style: theme.textTheme.bodyLarge,
        ),
        if (s.phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          Semantics(
            label: l.storeCallLabel,
            button: true,
            child: InkWell(
              onTap: () => _open(telUri(s.phone)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.phone, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () =>
                _open(mapsUri(s.latitude, s.longitude), maps: true),
            icon: const Icon(Icons.directions),
            label: Text(l.storeDirections),
          ),
        ),
        const SizedBox(height: 24),
        Text(l.storeHoursTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!hasHours)
          Text(
            l.storeHoursUnavailable,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OpenBadge(
              open: isOpenNow(data.hours, now),
              label: isOpenNow(data.hours, now)
                  ? l.storeOpenNow
                  : l.storeBadgeClosed,
            ),
          ),
          const SizedBox(height: 8),
          for (var d = 0; d < 7; d++) _hoursRow(l, data.hours, d, now),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => context.push(Routes.pay),
          icon: const Icon(Icons.payments_outlined),
          label: Text(l.storePay),
        ),
      ],
    );
  }

  Widget _hoursRow(
    AppLocalizations l,
    List<OpeningHoursRow> hours,
    int weekday,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final today = now.weekday - 1 == weekday;
    OpeningHoursRow? row;
    for (final h in hours) {
      if (h.weekday == weekday) row = h;
    }
    final style = today
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyLarge;
    return Container(
      key: today ? const ValueKey('hours-today') : null,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: today ? theme.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 2,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Text(weekdayNameFr(l, weekday), style: style),
          ),
          Text(
            row == null
                ? l.storeHoursClosedDay
                : l.storeHoursRange(_hm(row.opens), _hm(row.closes)),
            style: style,
          ),
        ],
      ),
    );
  }

  /// `HH:MM` of `HH:MM` or `HH:MM:SS`.
  String _hm(String t) => t.length > 5 ? t.substring(0, 5) : t;
}
