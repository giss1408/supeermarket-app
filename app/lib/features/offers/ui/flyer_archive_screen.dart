import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Placeholder replaced in place by a later task.
class FlyerArchiveScreen extends StatelessWidget {
  const FlyerArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabOffers)),
      body: Center(child: Text(l10n.placeholderFlyers)),
    );
  }
}
