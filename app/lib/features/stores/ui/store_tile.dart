import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/util/store_utils.dart';
import '../state/stores_providers.dart';
import '../../../core/theme/tokens.dart';

/// Open/closed pill shared by the list and the detail screen.
class OpenBadge extends StatelessWidget {
  const OpenBadge({super.key, required this.open, this.label});

  final bool open;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bg = open ? scheme.primaryContainer : scheme.errorContainer;
    final fg = open ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        label ?? (open ? l.storeBadgeOpen : l.storeBadgeClosed),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

class StoreTile extends StatelessWidget {
  const StoreTile({
    super.key,
    required this.item,
    required this.now,
    required this.onTap,
  });

  final StoreListItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = item.store;
    final km = item.distanceKm;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                l.storeAddressLine(s.address, s.city),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (km != null || item.hours.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (km != null)
                      Text(
                        formatDistanceFr(km),
                        style: theme.textTheme.labelLarge,
                      ),
                    if (item.hours.isNotEmpty)
                      OpenBadge(open: isOpenNow(item.hours, now)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
