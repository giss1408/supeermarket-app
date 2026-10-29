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
import 'package:supermarket_app/features/account/ui/sign_in_screen.dart';
import 'package:supermarket_app/features/lists/ui/list_detail_screen.dart';
import 'package:supermarket_app/features/lists/ui/lists_screen.dart';
import 'package:supermarket_app/features/offers/ui/flyer_archive_screen.dart';
import 'package:supermarket_app/features/offers/ui/offers_home_screen.dart';
import 'package:supermarket_app/features/payment/ui/pay_screen.dart';
import 'package:supermarket_app/features/stores/ui/store_detail_screen.dart';
import 'package:supermarket_app/features/stores/ui/stores_screen.dart';

/// Pumps the real app. [ref] is captured from a Consumer so tests can call
/// `requireSignIn`, which needs a WidgetRef.
class Harness {
  late WidgetRef ref;
  late ProviderContainer container;

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
      overrides: overrides,
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

      await t.tap(find.text('Se connecter (provisoire)'));
      await t.pumpAndSettle();
      expect(await future, isTrue);
      expect(h.location(t), '/lists');
      expect(find.byType(ListsScreen), findsOneWidget);
      expect(h.container.read(sessionProvider), isA<SignedIn>());
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
      h.container.read(sessionProvider.notifier).debugSignIn();
      final ctx = t.element(find.byType(OffersHomeScreen));
      expect(await requireSignIn(ctx, h.ref), isTrue);
      await t.pumpAndSettle();
      expect(find.byType(SignInScreen), findsNothing);
      expect(h.location(t), '/offers');
    });
  });

  test('sanitizeFrom', () {
    expect(sanitizeFrom('/lists'), '/lists');
    expect(sanitizeFrom('/stores/3?x=1'), '/stores/3?x=1');
    for (final bad in ['//evil.com', 'https://evil.com', 'evil', '', null]) {
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
