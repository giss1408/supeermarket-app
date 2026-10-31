import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/daos/sync_meta_keys.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/util/clock.dart';
import 'package:supermarket_app/features/account/ui/account_screen.dart';
import 'package:supermarket_app/features/payment/data/payment_repository.dart';
import 'package:supermarket_app/features/payment/state/payment_controller.dart';
import 'package:supermarket_app/features/payment/ui/pay_screen.dart';

import '../../core/db/test_db.dart';
import '../../support/fake_session_controller.dart';

const warning =
    'Ces numéros sont peut-être périmés. Confirmez le numéro à la caisse avant de payer.';

PaymentMethodRow row(String provider, String number, {String name = ''}) =>
    PaymentMethodRow(
      provider: provider,
      phoneNumber: number,
      displayName: name,
      instructions: 'Instructions $provider',
      updatedAt: '2026-11-03T10:00:00Z',
    );

/// Fake repository: real streams on an in-memory DB, scripted refresh.
class FakeRepo implements PaymentRepository {
  FakeRepo(this.db, this.now);
  final AppDatabase db;
  final DateTime now;
  int calls = 0;
  List<PaymentMethodRow> serverList = [];
  bool fail = false;
  Completer<void>? gate;

  @override
  Stream<List<PaymentMethodRow>> watchMethods() => db.paymentDao.watchMethods();

  @override
  Stream<DateTime?> watchLastChecked() => db.syncMetaDao
      .watch(paymentLastChecked)
      .map((v) => v == null ? null : DateTime.parse(v));

  @override
  Future<PaymentRefreshResult> refresh() async {
    calls++;
    await gate?.future;
    if (fail) return const Failed(NetworkError());
    await db.paymentDao.replaceMethods(serverList);
    await db.syncMetaDao.set(paymentLastChecked, now.toUtc().toIso8601String());
    return Refreshed(now);
  }
}

class Setup {
  Setup() {
    db = createTestDb();
    repo = FakeRepo(db, now);
  }
  late final AppDatabase db;
  late final FakeRepo repo;
  // Local time so the test does not depend on the machine's time zone.
  final now = DateTime(2026, 10, 31, 14, 32);

  Future<void> pump(
    WidgetTester t, {
    String initial = Routes.pay,
    double textScale = 1,
  }) async {
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(
        path: '/',
        builder: (c, _) => Scaffold(
          body: TextButton(
            onPressed: () => c.push(Routes.pay),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: Routes.pay, builder: (_, __) => const PayScreen()),
      GoRoute(path: Routes.account, builder: (_, __) => const AccountScreen()),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(ProviderScope(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
        sessionProvider.overrideWith(FakeSessionController.new),
      ],
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
    await settle(t);
  }
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Disposes the tree before the test ends so drift's stream timers finish.
void payTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    await body(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 10));
  });
}

final threeMethods = [
  row('wave', '+2250100000001'),
  row('orange_money', '+2250700000002'),
  row('mtn_momo', '+2250500000003'),
];

void main() {
  payTest('every_open_refreshes', (t) async {
    final s = Setup()..repo.serverList = threeMethods;
    await s.pump(t, initial: '/');
    await t.tap(find.text('open'));
    await settle(t);
    expect(s.repo.calls, 1);
    // Rebuilds do not refresh again.
    await t.pump(const Duration(seconds: 1));
    expect(s.repo.calls, 1);
    await t.tap(find.byType(BackButton));
    await settle(t);
    await t.tap(find.text('open'));
    await settle(t);
    expect(s.repo.calls, 2);
  });

  payTest('success_shows_cards_and_freshness', (t) async {
    final s = Setup()..repo.serverList = threeMethods;
    await s.pump(t);
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);
    expect(find.text('MTN MoMo'), findsOneWidget);
    expect(find.text('01 00 00 00 01'), findsOneWidget);
    expect(find.text('Instructions wave'), findsOneWidget);
    expect(find.text("Vérifié aujourd'hui à 14:32"), findsOneWidget);
    expect(find.text('Mis à jour le 3 nov.'), findsNWidgets(3));
    expect(find.text(warning), findsNothing);
  });

  payTest('failed_refresh_with_cache_shows_cache_and_warning', (t) async {
    final s = Setup()..repo.fail = true;
    await s.db.paymentDao.replaceMethods(threeMethods);
    await s.db.syncMetaDao
        .set(paymentLastChecked, DateTime(2026, 10, 30, 8).toIso8601String());
    await s.pump(t);
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text(warning), findsOneWidget);
    expect(find.textContaining('Vérifié'), findsNothing);
  });

  payTest('never_checked_and_failed_shows_warning_and_retry', (t) async {
    final s = Setup()..repo.fail = true;
    await s.pump(t);
    expect(find.text(warning), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    s.repo.fail = false;
    s.repo.serverList = threeMethods;
    await t.tap(find.text('Réessayer'));
    await settle(t);
    expect(s.repo.calls, 2);
    expect(find.text(warning), findsNothing);
    expect(find.text('Wave'), findsOneWidget);
  });

  payTest('loading_with_cache_shows_cache_without_warning', (t) async {
    final s = Setup();
    s.repo.gate = Completer<void>();
    await s.db.paymentDao.replaceMethods(threeMethods);
    await s.pump(t);
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text('Vérification en cours…'), findsOneWidget);
    expect(find.text(warning), findsNothing);
    s.repo.gate!.complete();
    s.repo.serverList = threeMethods;
    await settle(t);
  });

  payTest('empty_list_after_success_shows_empty_state', (t) async {
    final s = Setup();
    await s.pump(t);
    expect(
      find.text(
        'Aucun mode de paiement disponible pour le moment. Renseignez-vous à la caisse.',
      ),
      findsOneWidget,
    );
    expect(find.text(warning), findsNothing);
  });

  payTest('copy_puts_national_digits_on_clipboard', (t) async {
    final s = Setup()..repo.serverList = [row('wave', '+2250701020304')];
    String? copied;
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await s.pump(t);
    await t.tap(find.text('Copier le numéro'));
    await settle(t);
    expect(copied, '0701020304');
    expect(find.text('Numéro copié'), findsOneWidget);
  });

  payTest('invalid_stored_number_shows_raw_string', (t) async {
    final s = Setup()..repo.serverList = [row('wave', '12-34')];
    await s.pump(t);
    expect(find.text('12-34'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  payTest('account_button_navigates_to_pay', (t) async {
    final s = Setup()..repo.serverList = threeMethods;
    await s.pump(t, initial: Routes.account);
    await t.tap(find.text('Payer par mobile money'));
    await settle(t);
    expect(find.byType(PayScreen), findsOneWidget);
  });

  payTest('no_overflow_at_320dp_and_text_scale_2', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = Setup()..repo.fail = true;
    await s.db.paymentDao.replaceMethods([
      row('wave', '+2250701020304', name: 'Wave Cocody Angré'),
      row('orange_money', '+2250700000002'),
    ]);
    await s.pump(t, textScale: 2);
    expect(t.getSize(find.byType(Scaffold).first).width, 320);
    expect(find.text(warning), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
