import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/db/daos/public_dao.dart';
import '../../../core/money/xof.dart';
import '../../../core/ui/price_text.dart';

/// Product photo with a placeholder while loading, on error or when absent.
/// Photos are not cached for offline use in v1.
class OfferImage extends StatelessWidget {
  const OfferImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: scheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
    final u = url;
    return ExcludeSemantics(
      child: u == null || u.isEmpty
          ? placeholder
          : Image.network(
              u,
              fit: fit,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

/// Card of one offer in the grid. The whole card is the tap target.
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.item, required this.onTap});

  final OfferWithProduct item;
  final VoidCallback onTap;

  /// Image height = width * 3/4.
  static const imageAspectRatio = 4 / 3;

  /// Height of the text block at text scale 1.0 (name over two lines, unit,
  /// price and old price on two lines, paddings).
  static const _textBlockHeight = 168.0;

  /// Card height for a given width; grows with the text scale so large fonts
  /// do not overflow.
  static double heightFor(double width, TextScaler scaler) =>
      width / imageAspectRatio + scaler.scale(_textBlockHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final offer = item.offer;
    final product = item.product;
    final badge = offer.badgeText;

    final priceLabel = offer.oldPrice == null
        ? formatXof(offer.price)
        : l.priceWithOld(formatXof(offer.price), formatXof(offer.oldPrice!));
    final label =
        [product.name, priceLabel, if (badge.isNotEmpty) badge].join(', ');

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfferImage(url: product.imageUrl),
                    if (badge.isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        right: 8,
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: _BadgeChip(text: badge),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (product.unit.isNotEmpty)
                        Text(
                          product.unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const Spacer(),
                      PriceText(
                        price: offer.price,
                        oldPrice: offer.oldPrice,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

/// Badge chip shared with the detail sheet.
class OfferBadge extends StatelessWidget {
  const OfferBadge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => _BadgeChip(text: text);
}
