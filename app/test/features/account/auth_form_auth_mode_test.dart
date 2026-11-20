import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/features/account/ui/register_screen.dart';
import 'package:supermarket_app/features/account/ui/sign_in_screen.dart';

import '../../support/fake_session_controller.dart';

/// The form with the platform auth service: phone + password, then (new or not yet activated account) the WhatsApp code, or (temporary password) a new password.
Future<({FakeSessionController fake, List<bool?> results})> pump(WidgetTester t,
    {String open = '/sign-in'}) async {
  final fake = FakeSessionController();
  final results = <bool?>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
          body: TextButton(
              onPressed: () async =>
                  results.add(await context.push<bool>(open)),
              child: const Text('open'))),
    ),
    GoRoute(
        path: Routes.signInPath,
        builder: (_, s) => SignInScreen(from: s.uri.queryParameters['from'])),
    GoRoute(
        path: Routes.registerPath,
        builder: (_, s) => RegisterScreen(from: s.uri.queryParameters['from'])),
  ]);
  addTearDown(router.dispose);
  await t.pumpWidget(ProviderScope(
    overrides: [
      sessionProvider.overrideWith(() => fake),
      authBaseUrlProvider.overrideWithValue('https://auth.test')
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: lightTheme(Brand.neutral),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return (fake: fake, results: results);
}

Finder get _phone => find.byKey(const Key('field_phone'));
Finder get _password => find.byKey(const Key('field_password'));
Finder get _name => find.byKey(const Key('field_name'));
Finder get _code => find.byKey(const Key('field_code'));
Finder get _submit => find.byKey(const Key('auth_submit'));

ApiError api(String code, int status) =>
    ApiError(code: code, status: status, fields: const {});

void main() {
  testWidgets(
      'sign-in asks for a phone number (phone keyboard), not an e-mail, and offers "forgotten password"',
      (t) async {
    await pump(t);
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('Adresse e-mail'), findsNothing);
    expect(find.byKey(const Key('field_email')), findsNothing);
    expect(
        t
            .widget<TextField>(
                find.descendant(of: _phone, matching: find.byType(TextField)))
            .keyboardType,
        TextInputType.phone);
    expect(find.byKey(const Key('auth_forgot')), findsOneWidget);
  });

  testWidgets('signing in sends the phone and closes the form with true',
      (t) async {
    final h = await pump(t);
    await t.enterText(_phone, '07 01 02 03 04');
    await t.enterText(_password, 'secret-pass');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.signInCalls, [('07 01 02 03 04', 'secret-pass')]);
    expect(h.results, [true]);
  });

  testWidgets('wrong credentials are said with the phone wording', (t) async {
    final h = await pump(t);
    h.fake.failures['signIn'] = api('invalid_credentials', 401);
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'x');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.text('Numéro ou mot de passe incorrect.'), findsOneWidget);
    expect(h.results, isEmpty);
  });

  testWidgets(
      'sign-up: name, phone, password, then the WhatsApp code step; the code activates and closes the form',
      (t) async {
    final h = await pump(t, open: '/register');
    expect(_name, findsOneWidget);
    await t.enterText(_name, 'Awa');
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'secret-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.registerPhoneCalls,
        [(phone: '0701020304', password: 'secret-pass-1', name: 'Awa')]);
    expect(h.results, isEmpty, reason: 'not signed in yet');
    expect(find.text('Activez votre compte'), findsWidgets);
    expect(find.byKey(const Key('activation_info')), findsOneWidget);
    expect(_phone, findsNothing);
    expect(_code, findsOneWidget);
    await t.enterText(_code, '12');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.activateCalls, isEmpty, reason: 'six digits are needed');
    await t.enterText(_code, '123456');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.activateCalls,
        [(phone: '0701020304', code: '123456', password: 'secret-pass-1')]);
    expect(h.results, [true]);
  });

  testWidgets('a number that already has an account is told so', (t) async {
    final h = await pump(t, open: '/register');
    h.fake.failures['registerPhone'] = api('phone_taken', 409);
    await t.enterText(_name, 'Awa');
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'secret-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.text('Ce numéro a déjà un compte : connectez-vous.'),
        findsOneWidget);
    expect(_code, findsNothing);
  });

  testWidgets('a wrong code stays on the code step with the reason', (t) async {
    final h = await pump(t, open: '/register');
    await t.enterText(_name, 'Awa');
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'secret-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    h.fake.failures['activate'] = api('wrong_activation_code', 400);
    await t.enterText(_code, '000000');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.text('Code incorrect ou expiré.'), findsOneWidget);
    expect(_code, findsOneWidget);
    expect(h.results, isEmpty);
  });

  testWidgets(
      'signing in to an account never activated goes straight to the code step, keeping the typed password',
      (t) async {
    final h = await pump(t);
    h.fake.failures['signIn'] = api('not_activated', 403);
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'secret-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(_code, findsOneWidget);
    await t.enterText(_code, '123456');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.activateCalls.single.password, 'secret-pass-1');
    expect(h.results, [true]);
  });

  testWidgets(
      'a temporary password leads to the new-password step: both fields must match, then the form closes',
      (t) async {
    final h = await pump(t);
    h.fake.failures['signIn'] = const PasswordChangeRequired();
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'temp-pass');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.text('Choisissez votre mot de passe'), findsWidgets);
    expect(_phone, findsNothing);
    await t.enterText(
        find.byKey(const Key('field_new_password')), 'brand-new-pass-1');
    await t.enterText(
        find.byKey(const Key('field_new_password_confirm')), 'another-one');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(
        find.text('Les deux mots de passe sont différents.'), findsOneWidget);
    expect(h.fake.passwordChanges, isEmpty);
    await t.enterText(find.byKey(const Key('field_new_password_confirm')),
        'brand-new-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(h.fake.passwordChanges, ['brand-new-pass-1']);
    expect(h.results, [true]);
  });

  testWidgets(
      'forgotten password asks for the number first, then says the team will send a temporary one',
      (t) async {
    final h = await pump(t);
    await t.tap(find.byKey(const Key('auth_forgot')));
    await t.pumpAndSettle();
    expect(h.fake.resetCalls, isEmpty);
    await t.enterText(_phone, '07 01 02 03 04');
    await t.tap(find.byKey(const Key('auth_forgot')));
    await t.pumpAndSettle();
    expect(h.fake.resetCalls, ['07 01 02 03 04']);
    expect(find.byKey(const Key('auth_info')), findsOneWidget);
    expect(find.textContaining('mot de passe temporaire sur WhatsApp'),
        findsOneWidget);
  });

  testWidgets(
      'the switch between sign-in and sign-up is only on the first step',
      (t) async {
    await pump(t, open: '/register');
    expect(find.byKey(const Key('auth_switch')), findsOneWidget);
    await t.enterText(_name, 'Awa');
    await t.enterText(_phone, '0701020304');
    await t.enterText(_password, 'secret-pass-1');
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('auth_switch')), findsNothing);
  });

  testWidgets(
      'the original e-mail form is unchanged when the auth service is off',
      (t) async {
    final fake = FakeSessionController();
    final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const SignInScreen())]);
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
    expect(find.byKey(const Key('field_email')), findsOneWidget);
    expect(find.byKey(const Key('field_phone')), findsNothing);
    expect(find.byKey(const Key('auth_forgot')), findsNothing);
  });
}
