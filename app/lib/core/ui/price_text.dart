import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../money/xof.dart';

/// Price in XOF with tabular figures; optional struck-through old price.
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.price, this.oldPrice, this.style});

  final String price;
  final String? oldPrice;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final formatted = formatXof(price);
    final oldFormatted = oldPrice == null ? null : formatXof(oldPrice!);
    final base = (style ?? theme.textTheme.titleLarge)!.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final oldStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      decoration: TextDecoration.lineThrough,
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: oldFormatted == null
          ? formatted
          : l.priceWithOld(formatted, oldFormatted),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(formatted, style: base),
          if (oldFormatted != null) Text(oldFormatted, style: oldStyle),
        ],
      ),
    );
  }
}
