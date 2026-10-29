import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/features/account/ui/register_screen.dart';
import 'package:supermarket_app/features/account/ui/sign_in_screen.dart';

import '../../support/fake_session_controller.dart';

class Host {
  Host(this.fake);
  final FakeSessionController fake;
  bool? result;
  bool popped = false;
}

Future<Host> pumpHost(
  WidgetTester t, {
  Object? failWith,
  double textScale = 1.0,
  Size? size,
  String open = '/sign-in?from=%2Flists',
}) async {
  if (size != null) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }
  final fake = FakeSessionController(failWith: failWith);
  final host = Host(fake);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () async {
            host.result = await context.push<bool>(open);
            host.popped = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
    GoRoute(
      path: Routes.signInPath,
      builder: (_, s) => SignInScreen(from: s.uri.queryParameters['from']),
    ),
    GoRoute(
      path: Routes.registerPath,
      builder: (_, s) => RegisterScreen(from: s.uri.queryParameters['from']),
    ),
  ]);
  addTearDown(router.dispose);
  await t.pumpWidget(ProviderScope(
    overrides: [sessionProvider.overrideWith(() => fake)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: lightTheme(Brand.neutral),
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return host;
}

Finder get _email => find.byKey(const Key('field_email'));
Finder get _password => find.byKey(const Key('field_password'));
Finder get _name => find.byKey(const Key('field_name'));
Finder get _submit => find.byKey(const Key('auth_submit'));

Future<void> fill(WidgetTester t, {bool name = false}) async {
  await t.enterText(_email, ' awa@example.ci ');
  await t.enterText(_password, 'secret-pass');
  if (name) await t.enterText(_name, 'Awa');
}

ApiError api(String code, int status, [Map<String, List<String>>? fields]) =>
    ApiError(
      code: code,
      status: status,
      fields: fields ?? const {},
      detail: 'secret server detail',
    );

void main() {
  testWidgets('forms are French, with the right keyboards and autofill hints',
      (t) async {
    await pumpHost(t);
    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Adresse e-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    final email = t.widget<TextField>(
        find.descendant(of: _email, matching: find.byType(TextField)));
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, [AutofillHints.username]);
    final pw = t.widget<TextField>(
        find.descendant(of: _password, matching: find.byType(TextField)));
    expect(pw.obscureText, isTrue);
    expect(pw.autofillHints, [AutofillHints.password]);
    expect(pw.textInputAction, TextInputAction.done);
    expect(_name, findsNothing);
  });

  testWidgets('register form has name, email and new-password hints',
      (t) async {
    await pumpHost(t, open: '/register');
    expect(find.text('Créer un compte'), findsWidgets);
    expect(_name, findsOneWidget);
    final pw = t.widget<TextField>(
        find.descendant(of: _password, matching: find.byType(TextField)));
    expect(pw.autofillHints, [AutofillHints.newPassword]);
    final email = t.widget<TextField>(
        find.descendant(of: _email, matching: find.byType(TextField)));
    expect(email.autofillHints, [AutofillHints.email]);
  });

  testWidgets('field errors from ApiError.fields appear under their fields',
      (t) async {
    final host = await pumpHost(
      t,
      open: '/register',
      failWith: api('validation_error', 400, {
        'email': ['Cette adresse est déjà utilisée.'],
        'password': ['Ce mot de passe est trop court.', 'Trop courant.'],
        'name': ['Nom trop long.'],
      }),
    );
    await fill(t, name: true);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(host.fake.registerCalls, 1);
    for (final (key, msg) in [
      (_email, 'Cette adresse est déjà utilisée.'),
      (_password, 'Ce mot de passe est trop court.'),
      (_name, 'Nom trop long.'),
    ]) {
      expect(
        find.descendant(of: key, matching: find.textContaining(msg)),
        findsOneWidget,
        reason: msg,
      );
    }
    expect(find.byKey(const Key('auth_banner')), findsNothing);
    expect(find.textContaining('secret server detail'), findsNothing);
    // Editing a field clears only its own error.
    await t.enterText(_email, 'x@y.ci');
    await t.pump();
    expect(find.text('Cette adresse est déjà utilisée.'), findsNothing);
    expect(
        find.textContaining('Ce mot de passe est trop court.'), findsOneWidget);
  });

  testWidgets('non_field_errors and unknown keys appear in a banner',
      (t) async {
    await pumpHost(
      t,
      failWith: api('validation_error', 400, {
        'non_field_errors': ['Impossible de se connecter.'],
        'weird': ['Autre souci.'],
      }),
    );
    await fill(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    final banner = find.byKey(const Key('auth_banner'));
    expect(banner, findsOneWidget);
    expect(
        find.descendant(
            of: banner,
            matching: find.textContaining('Impossible de se connecter.')),
        findsOneWidget);
    expect(
        find.descendant(
            of: banner, matching: find.textContaining('Autre souci.')),
        findsOneWidget);
  });

  testWidgets('wrong credentials 401 shows the credentials message', (t) async {
    await pumpHost(t, failWith: api('not_authenticated', 401));
    await fill(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(
        find.text('Adresse e-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.textContaining('session a expiré'), findsNothing);
  });

  testWidgets('throttle error banner text', (t) async {
    await pumpHost(t, failWith: api('throttled', 429));
    await fill(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('auth_banner')),
        matching:
            find.text('Trop de requêtes. Patientez un instant puis réessayez.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('network error shows the offline message', (t) async {
    await pumpHost(t, failWith: const NetworkError());
    await fill(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('auth_banner')), findsOneWidget);
    // The button works again after the failure.
    expect(t.widget<FilledButton>(_submit).onPressed, isNotNull);
  });

  testWidgets('empty fields are rejected locally without a request', (t) async {
    final host = await pumpHost(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(2));
    expect(host.fake.signInCalls, isEmpty);
  });

  testWidgets('busy state disables the button; a second tap sends nothing',
      (t) async {
    final host = await pumpHost(t);
    final gate = Completer<void>();
    host.fake.gate = () => gate.future;
    await fill(t);
    await t.tap(_submit);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<FilledButton>(_submit).onPressed, isNull);
    await t.tap(_submit, warnIfMissed: false);
    await t.pump();
    expect(host.fake.signInCalls, hasLength(1));
    gate.complete();
    await t.pumpAndSettle();
    expect(host.result, isTrue);
  });

  testWidgets('success pops true and passes the raw email to the controller',
      (t) async {
    final host = await pumpHost(t);
    await fill(t);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(host.result, isTrue);
    expect(host.fake.signInCalls.single.$2, 'secret-pass');
    expect(host.fake.state, isA<SignedIn>());
  });

  testWidgets('keyboard done on the password field submits', (t) async {
    final host = await pumpHost(t);
    await fill(t);
    await t.tap(_password);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(host.fake.signInCalls, hasLength(1));
    expect(host.result, isTrue);
  });

  testWidgets('close pops false', (t) async {
    final host = await pumpHost(t);
    await t.tap(find.byTooltip('Fermer'));
    await t.pumpAndSettle();
    expect(host.popped, isTrue);
    expect(host.result, isFalse);
    expect(host.fake.signInCalls, isEmpty);
  });

  testWidgets('register <-> sign-in switch preserves from; register signs in',
      (t) async {
    final host = await pumpHost(t);
    await t.tap(find.byKey(const Key('auth_switch')));
    await t.pumpAndSettle();
    expect(host.popped, isFalse, reason: 'switching must not complete push');
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(
        t.widget<RegisterScreen>(find.byType(RegisterScreen)).from, '/lists');
    await t.tap(find.byKey(const Key('auth_switch')));
    await t.pumpAndSettle();
    expect(t.widget<SignInScreen>(find.byType(SignInScreen)).from, '/lists');
    await t.tap(find.byKey(const Key('auth_switch')));
    await t.pumpAndSettle();
    await fill(t, name: true);
    await t.tap(_submit);
    await t.pumpAndSettle();
    expect(host.fake.registerCalls, 1);
    expect(find.byType(RegisterScreen), findsNothing);
    expect(host.fake.state, isA<SignedIn>());
  });

  testWidgets('password show/hide toggle', (t) async {
    await pumpHost(t);
    bool obscured() => t
        .widget<TextField>(
            find.descendant(of: _password, matching: find.byType(TextField)))
        .obscureText;
    expect(obscured(), isTrue);
    await t.tap(find.byTooltip('Afficher le mot de passe'));
    await t.pump();
    expect(obscured(), isFalse);
    await t.tap(find.byTooltip('Masquer le mot de passe'));
    await t.pump();
    expect(obscured(), isTrue);
  });

  for (final route in ['/sign-in', '/register']) {
    testWidgets('no overflow at 320 dp and text scale 2.0: $route', (t) async {
      final handle = t.ensureSemantics();
      await pumpHost(
        t,
        open: route,
        size: const Size(320, 640),
        textScale: 2.0,
        failWith: api('validation_error', 400, {
          'email': ['Cette adresse e-mail est déjà utilisée par un compte.'],
          'password': [
            'Ce mot de passe est trop court. Il doit contenir au minimum 8 caractères.'
          ],
          'non_field_errors': [
            'Une erreur générale assez longue pour passer à la ligne.'
          ],
        }),
      );
      await fill(t, name: route == '/register');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(t.view.physicalSize.width, 320);
      // Interactive targets are at least 48 dp.
      for (final f in [_submit, find.byKey(const Key('auth_switch'))]) {
        expect(t.getSize(f).height, greaterThanOrEqualTo(48));
      }
      expect(
          t.getSize(find.widgetWithIcon(IconButton, Icons.close)).shortestSide,
          greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Adresse e-mail'), findsWidgets);
      handle.dispose();
    });
  }
}
