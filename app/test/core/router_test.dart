import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/app.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/router/app_router.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/router/sign_in_gate.dart';
import 'package:supermarket_app/core/ui/not_found_page.dart';
import 'package:supermarket_app/features/account/ui/account_screen.dart';
import 'package:supermarket_app/features/account/ui/register_screen.dart';
import 'package:supermarket_app/features/account/ui/sign_in_screen.dart';
import 'package:supermarket_app/features/lists/ui/list_detail_screen.dart';
import 'package:supermarket_app/features/lists/ui/lists_screen.dart';
import 'package:supermarket_app/features/offers/ui/flyer_archive_screen.dart';
import 'package:supermarket_app/features/offers/ui/offers_home_screen.dart';
import 'package:supermarket_app/features/payment/ui/pay_screen.dart';
import 'package:supermarket_app/features/stores/ui/store_detail_screen.dart';
import 'package:supermarket_app/features/stores/ui/stores_screen.dart';

import '../support/fake_session_controller.dart';

/// Pumps the real app. [ref] is captured from a Consumer so tests can call
/// `requireSignIn`, which needs a WidgetRef.
class Harness {
  late WidgetRef ref;
  late ProviderContainer container;

  FakeSessionController get fake =>
      container.read(sessionProvider.notifier) as FakeSessionController;

  GoRouter router(WidgetTester t) =>
      container.read(appRouterProvider); // same instance the app watches

  String location(WidgetTester t) => currentLocation(router(t));
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final h = Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(FakeSessionController.new),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          h.ref = ref;
          h.container = ProviderScope.containerOf(context);
          return const SupermarketApp();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

/// Fills the real sign-in/register form and submits it (the fake controller
/// signs in successfully).
Future<void> submitForm(WidgetTester t) async {
  await t.enterText(find.byKey(const Key('field_email')), 'u7@example.ci');
  await t.enterText(find.byKey(const Key('field_password')), 'secret-pass');
  await t.tap(find.byKey(const Key('auth_submit')));
  await t.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('tabs', () {
    testWidgets('four French tabs in order, initial tab Offres', (t) async {
      final h = await pumpApp(t);
      final labels = t
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label)
          .toList();
      expect(labels, ['Offres', 'Listes', 'Magasins', 'Compte']);
      expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
      expect(find.byType(OffersHomeScreen), findsOneWidget);
      expect(h.location(t), '/offers');
    });

    testWidgets('tapping each tab shows its placeholder', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Listes');
      expect(find.byType(ListsScreen), findsOneWidget);
      await tapTab(t, 'Magasins');
      expect(find.byType(StoresScreen), findsOneWidget);
      await tapTab(t, 'Compte');
      expect(find.byType(AccountScreen), findsOneWidget);
      await tapTab(t, 'Offres');
      expect(find.byType(OffersHomeScreen), findsOneWidget);
    });

    testWidgets('destinations are 48dp and have tooltips', (t) async {
      await pumpApp(t);
      for (final d in t.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      )) {
        expect(d.tooltip, d.label);
      }
      final size = t.getSize(find.byType(NavigationDestination).first);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('each tab keeps its own stack', (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Magasins');
      h.router(t).go(Routes.storeDetail(3));
      await t.pumpAndSettle();
      expect(find.byType(StoreDetailScreen), findsOneWidget);
      await tapTab(t, 'Offres');
      expect(find.byType(OffersHomeScreen), findsOneWidget);
      await tapTab(t, 'Magasins');
      expect(find.byType(StoreDetailScreen), findsOneWidget);
      expect(h.location(t), '/stores/3');
    });

    testWidgets('tapping the selected tab returns to the branch root',
        (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Magasins');
      h.router(t).go(Routes.storeDetail(3));
      await t.pumpAndSettle();
      await tapTab(t, 'Magasins');
      expect(find.byType(StoresScreen), findsOneWidget);
      expect(find.byType(StoreDetailScreen), findsNothing);
      expect(h.location(t), '/stores');
    });

    testWidgets('scroll offset is kept per tab', (t) async {
      final testRouter = buildAppRouter(offersRoutes: [
        GoRoute(
          path: 'scroll',
          builder: (context, state) => Scaffold(
            body: ListView.builder(
              key: const PageStorageKey('scroll-test'),
              itemCount: 200,
              itemBuilder: (_, i) =>
                  SizedBox(height: 50, child: Text('row $i')),
            ),
          ),
        ),
      ]);
      addTearDown(testRouter.dispose);
      final h = await pumpApp(t, overrides: [
        appRouterProvider.overrideWithValue(testRouter),
      ]);
      testRouter.go('/offers/scroll');
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, -1000));
      await t.pumpAndSettle();
      double offset() => t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      final before = offset();
      expect(before, greaterThan(500));
      await tapTab(t, 'Listes');
      expect(find.byType(ListsScreen), findsOneWidget);
      await tapTab(t, 'Offres');
      expect(offset(), before);
      expect(h.location(t), '/offers/scroll');
    });
  });

  group('routes', () {
    testWidgets('/offers/flyers shows the archive inside the shell', (t) async {
      final h = await pumpApp(t);
      h.router(t).go(Routes.flyerArchive);
      await t.pumpAndSettle();
      expect(find.byType(FlyerArchiveScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('/pay is reachable as guest without bottom bar', (t) async {
      final h = await pumpApp(t);
      h.router(t).go(Routes.pay);
      await t.pumpAndSettle();
      expect(find.byType(PayScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    for (final path in ['/nope', '/stores/abc']) {
      testWidgets('$path shows the French not-found page', (t) async {
        final h = await pumpApp(t);
        h.router(t).go(path);
        await t.pumpAndSettle();
        expect(find.byType(NotFoundPage), findsOneWidget);
        expect(find.text('Page introuvable'), findsWidgets);
        await t.tap(find.text('Retour aux offres'));
        await t.pumpAndSettle();
        expect(find.byType(OffersHomeScreen), findsOneWidget);
        expect(h.location(t), '/offers');
      });
    }

    testWidgets('deep link to a list id', (t) async {
      final h = await pumpApp(t);
      const id = '3f2c1b7e-9a54-4d0e-8c1a-0123456789ab';
      h.router(t).go(Routes.listDetail(id));
      await t.pumpAndSettle();
      final screen = t.widget<ListDetailScreen>(find.byType(ListDetailScreen));
      expect(screen.listId, id);
    });

    testWidgets('fresh container gives a different router', (t) async {
      final a = ProviderContainer();
      final b = ProviderContainer();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(identical(a.read(appRouterProvider), b.read(appRouterProvider)),
          isFalse);
    });
  });

  group('requireSignIn', () {
    testWidgets('guest: opens sign-in with from, returns true after sign-in',
        (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Listes');
      final ctx = t.element(find.byType(ListsScreen));
      final future = requireSignIn(ctx, h.ref);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.widget<SignInScreen>(find.byType(SignInScreen)).from, '/lists');
      expect(h.location(t), '/sign-in?from=%2Flists');

      await submitForm(t);
      await t.pumpAndSettle();
      expect(await future, isTrue);
      expect(h.location(t), '/lists');
      expect(find.byType(ListsScreen), findsOneWidget);
      expect(h.container.read(sessionProvider), isA<SignedIn>());
    });

    testWidgets('switching to register keeps the gate waiting, then true',
        (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Listes');
      final ctx = t.element(find.byType(ListsScreen));
      var done = false;
      final future = requireSignIn(ctx, h.ref).whenComplete(() => done = true);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('auth_switch')));
      await t.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(
          t.widget<RegisterScreen>(find.byType(RegisterScreen)).from, '/lists');
      expect(done, isFalse);
      await submitForm(t);
      expect(await future, isTrue);
      expect(h.location(t), '/lists');
    });

    testWidgets('closing the register screen after a switch returns false',
        (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Listes');
      final ctx = t.element(find.byType(ListsScreen));
      final future = requireSignIn(ctx, h.ref);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('auth_switch')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Fermer'));
      await t.pumpAndSettle();
      expect(await future, isFalse);
      expect(h.container.read(sessionProvider), isA<Guest>());
      expect(h.location(t), '/lists');
      // The gate is free again.
      final again = requireSignIn(ctx, h.ref);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await t.tap(find.byTooltip('Fermer'));
      await t.pumpAndSettle();
      expect(await again, isFalse);
    });

    testWidgets('closing the dialog returns false and stays Guest', (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Listes');
      final ctx = t.element(find.byType(ListsScreen));
      final future = requireSignIn(ctx, h.ref);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Fermer'));
      await t.pumpAndSettle();
      expect(await future, isFalse);
      expect(h.container.read(sessionProvider), isA<Guest>());
      expect(h.location(t), '/lists');
    });

    testWidgets('signed in returns true without navigation', (t) async {
      final h = await pumpApp(t);
      h.fake.force(const SignedIn(FakeSessionController.user));
      final ctx = t.element(find.byType(OffersHomeScreen));
      expect(await requireSignIn(ctx, h.ref), isTrue);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsNothing);
      expect(h.location(t), '/offers');
    });
  });

  test('sanitizeFrom accepts known locations', () {
    for (final ok in [
      '/lists',
      '/lists/3f2c1b7e-9a54',
      '/stores/3?x=1',
      '/offers/flyers',
      '/pay',
      '/account',
    ]) {
      expect(sanitizeFrom(ok), ok);
    }
  });

  test('sanitizeFrom rejects hostile or unknown values', () {
    for (final bad in <String?>[
      null,
      '',
      'evil',
      '//evil.com',
      '///x',
      '/\\evil.com',
      '/\\\\evil.com',
      '/a\\b',
      '/lists\\x',
      'https://evil.com',
      'https:evil',
      'javascript:alert(1)',
      ' /lists',
      '/lists ',
      '/lists\n',
      '/\t/evil.com',
      '/lists\u0000',
      '/%2F%2Fevil.com',
      '/%2fevil.com',
      '/%5Cevil.com',
      '/lists/%0A',
      '/lists/../x',
      '/lists/./x',
      '/lists/..',
      '/..',
      '/${'a' * 3000}',
      '/unknown',
      '/signin',
      '/sign-in',
      '/sign-in?from=/lists',
      '/register',
      '/register?from=/lists',
    ]) {
      expect(sanitizeFrom(bad), isNull, reason: '$bad');
    }
  });

  test('Routes helpers', () {
    expect(Routes.offers, '/offers');
    expect(Routes.flyerArchive, '/offers/flyers');
    expect(Routes.lists, '/lists');
    expect(Routes.listDetail('abc'), '/lists/abc');
    expect(Routes.stores, '/stores');
    expect(Routes.storeDetail(7), '/stores/7');
    expect(Routes.account, '/account');
    expect(Routes.pay, '/pay');
    expect(Routes.signIn(), '/sign-in');
    expect(Routes.register(), '/register');
    expect(Routes.signIn(from: '/lists'), '/sign-in?from=%2Flists');
    expect(Routes.register(from: '/stores/3?x=1'),
        '/register?from=%2Fstores%2F3%3Fx%3D1');
  });

  group('sign-in gate hardening', () {
    testWidgets('no throw when the origin is unmounted mid-dialog', (t) async {
      final show = ValueNotifier<bool>(true);
      addTearDown(show.dispose);
      late BuildContext originCtx;
      late WidgetRef originRef;
      final testRouter = buildAppRouter(offersRoutes: [
        GoRoute(
          path: 'origin',
          builder: (context, state) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, visible, __) => visible
                  ? Consumer(builder: (c, ref, _) {
                      originCtx = c;
                      originRef = ref;
                      return const Text('origin');
                    })
                  : const SizedBox(),
            ),
          ),
        ),
      ]);
      addTearDown(testRouter.dispose);
      final h = await pumpApp(t, overrides: [
        appRouterProvider.overrideWithValue(testRouter),
      ]);
      testRouter.go('/offers/origin');
      await t.pumpAndSettle();
      final future = requireSignIn(originCtx, originRef);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      show.value = false; // dispose the originating Consumer
      await t.pump();
      expect(find.text('origin'), findsNothing);
      await submitForm(t);
      await t.pumpAndSettle();
      expect(await future, isTrue);
      expect(t.takeException(), isNull);
      expect(h.container.read(sessionProvider), isA<SignedIn>());
    });

    testWidgets('overlapping calls push exactly one sign-in route', (t) async {
      final h = await pumpApp(t);
      await tapTab(t, 'Listes');
      final ctx = t.element(find.byType(ListsScreen));
      final f1 = requireSignIn(ctx, h.ref);
      final f2 = requireSignIn(ctx, h.ref);
      expect(identical(f1, f2), isTrue);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        t.widget<SignInScreen>(find.byType(SignInScreen)).from,
        '/lists',
      );
      await submitForm(t);
      await t.pumpAndSettle();
      expect(await f1, isTrue);
      expect(await f2, isTrue);
      expect(find.byType(SignInScreen), findsNothing);
      // A new call works again after completion (guest again).
      h.fake.force(const Guest());
      final f3 = requireSignIn(ctx, h.ref);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await t.tap(find.byTooltip('Fermer'));
      await t.pumpAndSettle();
      expect(await f3, isFalse);
    });
  });

  group('router-level from sanitizing and register', () {
    for (final entry in {
      Routes.signInPath: SignInScreen,
      Routes.registerPath: RegisterScreen,
    }.entries) {
      testWidgets('${entry.key} sanitizes from', (t) async {
        final h = await pumpApp(t);
        h.router(t).go('${entry.key}?from=%2F%2Fevil.com');
        await t.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(_fromOf(t, entry.value), isNull);
        h.router(t).go('${entry.key}?from=%2Flists');
        await t.pumpAndSettle();
        expect(_fromOf(t, entry.value), '/lists');
      });
    }

    testWidgets('register is a dialog popping true / false', (t) async {
      final h = await pumpApp(t);
      final router = h.router(t);
      var f = router.push<bool>(Routes.register(from: '/lists'));
      await t.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await submitForm(t);
      await t.pumpAndSettle();
      expect(await f, isTrue);
      expect(find.byType(RegisterScreen), findsNothing);
      f = router.push<bool>(Routes.register());
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Fermer'));
      await t.pumpAndSettle();
      expect(await f, isFalse);
    });

    testWidgets('list ids are encoded and decoded', (t) async {
      final h = await pumpApp(t);
      const id = 'a/b?c#d e';
      final path = Routes.listDetail(id);
      expect(path, '/lists/a%2Fb%3Fc%23d%20e');
      h.router(t).go(path);
      await t.pumpAndSettle();
      expect(
        t.widget<ListDetailScreen>(find.byType(ListDetailScreen)).listId,
        id,
      );
    });

    test('from encoding', () {
      expect(Routes.signIn(from: '/lists/3?x=1'),
          '/sign-in?from=%2Flists%2F3%3Fx%3D1');
      expect(Routes.register(from: '/lists/3?x=1'),
          '/register?from=%2Flists%2F3%3Fx%3D1');
    });
  });

  group('320dp at text scale 2.0', () {
    Future<void> pumpAt320(WidgetTester t, String path) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await pumpApp(t);
      h.router(t).go(path);
      await t.pumpAndSettle();
    }

    testWidgets('bottom bar does not overflow', (t) async {
      await pumpAt320(t, '/offers');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('not-found page does not overflow', (t) async {
      await pumpAt320(t, '/nope');
      expect(find.byType(NotFoundPage), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}

String? _fromOf(WidgetTester t, Type type) {
  final w = t.widget(find.byType(type));
  return w is SignInScreen ? w.from : (w as RegisterScreen).from;
}
