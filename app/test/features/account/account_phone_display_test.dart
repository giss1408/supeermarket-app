import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/features/account/ui/account_screen.dart';

import '../../support/fake_session_controller.dart';

Future<void> pump(WidgetTester t, SessionUser user) async {
  final fake = FakeSessionController(startIn: SignedIn(user));
  final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const AccountScreen())]);
  addTearDown(router.dispose);
  await t.pumpWidget(ProviderScope(
    overrides: [sessionProvider.overrideWith(() => fake)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: lightTheme(Brand.neutral),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'a person who signed in through the auth service has no e-mail: the account shows her masked number',
      (t) async {
    await pump(
        t,
        const SessionUser(
            id: '1', email: '', name: 'Awa', phone: '07 •• •• 03 04'));
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('07 •• •• 03 04'), findsOneWidget);
  });

  testWidgets('with the original sign-in the e-mail is still what is shown',
      (t) async {
    await pump(
        t, const SessionUser(id: '1', email: 'awa@example.ci', name: 'Awa'));
    expect(find.text('awa@example.ci'), findsOneWidget);
  });
}
