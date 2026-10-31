import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session_controller.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_coordinator.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand.dart';

class SupermarketApp extends ConsumerStatefulWidget {
  const SupermarketApp({super.key});

  @override
  ConsumerState<SupermarketApp> createState() => _SupermarketAppState();
}

class _SupermarketAppState extends ConsumerState<SupermarketApp> {
  @override
  void initState() {
    super.initState();
    // Restore the session without blocking the first frame; the app shows
    // content (as a guest) meanwhile. restore() never throws.
    Future<void>(() => ref.read(sessionProvider.notifier).restore());
    // Offline-first list sync: starts after the first frame is requested and
    // reacts to sign-in, connectivity and app resume by itself.
    Future<void>(() => ref.read(syncCoordinatorProvider).start());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme(Brand.neutral),
      darkTheme: darkTheme(Brand.neutral),
      themeMode: ThemeMode.system,
      locale: AppConfig.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
