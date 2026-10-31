import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/device/screen_controller.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/router/sign_in_gate.dart';
import 'package:supermarket_app/core/sync/sync_coordinator.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/features/account/ui/account_screen.dart';
import 'package:supermarket_app/features/card/ui/card_screen.dart';

import 'auth_harness.dart';
import 'fake_http.dart';

class FakeScreenController implements ScreenController {
  final calls = <String>[];

  @override
  Future<void> boostBrightness() async => calls.add('boost');

  @override
  Future<void> restoreBrightness() async => calls.add('restore');

  @override
  Future<void> keepAwake(bool on) async => calls.add('awake:$on');
}

/// Sync coordinator whose `run` just records the call.
class FakeSync implements SyncCoordinator {
  int runs = 0;
  Future<void> Function()? onRun;

  @override
  SyncStatus get status => const SyncIdle();

  @override
  Future<void> run({bool force = false}) async {
    runs++;
    await onRun?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> meCardFixture() => jsonDecode(
      File('test/fixtures/me_card.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Everything async-stateful (guard, database, session) must be created in the
/// REAL zone: futures made inside the widget tester's fake zone never complete
/// unless pumped. Hence [AccountEnv.create] and [real].
class AccountEnv {
  AccountEnv._(this._tester) {
    h = createAuthHarness(overrides: [
      screenControllerProvider.overrideWithValue(screen),
      syncCoordinatorProvider.overrideWithValue(sync),
    ]);
  }

  static Future<AccountEnv> create(WidgetTester t) async =>
      (await t.runAsync(() async => AccountEnv._(t)))!;

  /// For plain `test()` bodies, where no fake zone exists.
  static AccountEnv plain() => AccountEnv._(null);

  final WidgetTester? _tester;

  /// Runs [body] in the real zone (widget tests) or directly (plain tests).
  Future<T> real<T>(Future<T> Function() body) async {
    final t = _tester;
    return t == null ? body() : (await t.runAsync(body)) as T;
  }

  final screen = FakeScreenController();
  final sync = FakeSync();
  late final AuthHarness h;
  late GoRouter router;

  String get location => currentLocation(router);

  /// Signs user [id] in through the real controller.
  Future<void> signIn(int id, {String name = 'Awa Koné'}) {
    h.stubLogin();
    h.stubMe(id, name: name);
    return real(() => h.session.signIn('u$id@example.ci', 'pw'));
  }

  Future<void> pump(
    WidgetTester t, {
    String initial = Routes.account,
    String? email,
  }) async {
    router = GoRouter(initialLocation: initial, routes: [
      GoRoute(
        path: Routes.offers,
        builder: (_, __) => const Scaffold(body: Text('PAGE_OFFERS')),
      ),
      GoRoute(path: Routes.account, builder: (_, __) => const AccountScreen()),
      GoRoute(
        path: Routes.pay,
        builder: (_, __) => const Scaffold(body: Text('PAGE_PAY')),
      ),
      GoRoute(path: Routes.card, builder: (_, __) => const CardScreen()),
      GoRoute(
        path: Routes.signInPath,
        builder: (_, __) => const Scaffold(body: Text('PAGE_SIGN_IN')),
      ),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: lightTheme(Brand.neutral),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await settle(t);
  }
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    // Real time too: drift delivers stream events on real-zone timers.
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Disposes the tree so drift's stream timers finish before the test ends.
void screenTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

FakeHandler cardReply(Map<String, dynamic> body) =>
    (_, __) => FakeResponse(200, body);
