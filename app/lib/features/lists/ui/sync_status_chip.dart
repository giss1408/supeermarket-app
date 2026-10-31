import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_coordinator.dart';
import '../state/lists_providers.dart';

/// Read-only sync indicator: nothing when idle and fully synced.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final status = ref.watch(syncStatusProvider);
    final pending = ref.watch(pendingCountProvider).valueOrNull ?? 0;
    final (String, IconData)? content = switch (status) {
      SyncOffline() => (l.syncOffline, Icons.cloud_off),
      SyncFailed() => (l.syncError, Icons.sync_problem),
      SyncSyncing() => (l.syncSyncing, Icons.sync),
      SyncIdle() when pending > 0 => (l.syncPending(pending), Icons.schedule),
      _ => null,
    };
    if (content == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isError = status is SyncFailed;
    final color =
        isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          key: const Key('sync_chip'),
          decoration: BoxDecoration(
            color: isError ? scheme.errorContainer : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(content.$2, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    content.$1,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
