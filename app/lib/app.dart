import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).appName)),
      ),
    ),
  ],
);

/// Placeholder shell; the real router and theme arrive in later tasks.
class SupermarketApp extends ConsumerWidget {
  const SupermarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme(Brand.neutral),
      darkTheme: darkTheme(Brand.neutral),
      themeMode: ThemeMode.system,
      locale: AppConfig.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
