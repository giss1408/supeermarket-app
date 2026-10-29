import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Shell with the four-tab bottom bar. Each branch keeps its own stack.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget dest(String label, IconData icon, IconData selected) =>
        NavigationDestination(
          icon: Icon(icon),
          selectedIcon: Icon(selected),
          label: label,
          tooltip: label,
        );
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          dest(l10n.tabOffers, Icons.local_offer_outlined, Icons.local_offer),
          dest(l10n.tabLists, Icons.checklist_outlined, Icons.checklist),
          dest(l10n.tabStores, Icons.storefront_outlined, Icons.storefront),
          dest(l10n.tabAccount, Icons.person_outline, Icons.person),
        ],
      ),
    );
  }
}
