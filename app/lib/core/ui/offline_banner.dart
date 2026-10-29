import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).offlineBanner,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
