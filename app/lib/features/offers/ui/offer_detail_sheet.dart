import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/db/daos/public_dao.dart';
import '../../../core/ui/date_format_fr.dart';
import '../../../core/ui/price_text.dart';
import 'offer_card.dart';
import '../../../core/theme/tokens.dart';

/// Detail of one offer, shown in a modal bottom sheet. The "add to a list"
/// button only exists when [onAddToList] is given.
class OfferDetailSheet extends StatelessWidget {
  const OfferDetailSheet({super.key, required this.item, this.onAddToList});

  final OfferWithProduct item;
  final VoidCallback? onAddToList;

  static Future<void> show(
    BuildContext context,
    OfferWithProduct item, {
    VoidCallback? onAddToList,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => OfferDetailSheet(item: item, onAddToList: onAddToList),
      );

  String? _validity(AppLocalizations l) {
    final from = item.offer.validFrom;
    final to = item.offer.validTo;
    try {
      if (from != null && to != null) {
        return l.offerDetailValidity(formatDateRangeFr(from, to));
      }
      if (to != null) return l.offerDetailValidUntil(formatDayFr(to));
      if (from != null) return l.offerDetailValidFrom(formatDayFr(from));
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final offer = item.offer;
    final product = item.product;
    final validity = _validity(l);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: OfferImage(url: product.imageUrl),
            ),
          ),
          const SizedBox(height: 16),
          if (offer.badgeText.isNotEmpty) ...[
            OfferBadge(text: offer.badgeText),
            const SizedBox(height: 8),
          ],
          Text(product.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          PriceText(
            price: offer.price,
            oldPrice: offer.oldPrice,
            style: theme.textTheme.headlineMedium,
          ),
          if (product.unit.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.offerDetailUnit(product.unit), style: muted),
          ],
          if (item.category != null) ...[
            const SizedBox(height: 4),
            Text(l.offerDetailCategory(item.category!.name), style: muted),
          ],
          if (validity != null) ...[
            const SizedBox(height: 4),
            Text(validity, style: muted),
          ],
          if (product.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(product.description, style: theme.textTheme.bodyLarge),
          ],
          if (onAddToList != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddToList,
                icon: const Icon(Icons.playlist_add),
                label: Text(l.offerDetailAddToList),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
