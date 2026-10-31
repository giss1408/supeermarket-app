import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/router/routes.dart';
import 'package:supermarket_app/core/sync/refresh_outcome.dart';
import 'package:supermarket_app/features/card/data/card_repository.dart';

import '../../support/account_harness.dart';
import '../../support/fake_http.dart';

void main() {
  screenTest('renders_cached_card_toggles_qr_and_manages_the_screen',
      (t) async {
    final env = await AccountEnv.create(t);
    await env.signIn(1);
    await env.real(
      () => env.h.db.cardDao.setCard('0419095719373', '0419095719373'),
    );
    env.h.http.on('GET', '/api/v1/me/card', offline());
    await env.pump(t, initial: Routes.card);

    expect(find.text('0419 0957 1937 3'), findsOneWidget);
    final code = t.widget<BarcodeWidget>(find.byKey(const Key('card_barcode')));
    expect(utf8.decode(code.data as List<int>), '0419095719373');
    expect(code.barcode.name, 'CODE 128');
    expect(find.text('Présentez ce code à la caisse'), findsOneWidget);
    // Offline refresh failed, yet the cached card stays on screen.
    expect(env.h.http.callsTo('/me/card'), hasLength(1));
    expect(env.screen.calls, ['boost', 'awake:true']);

    await t.tap(find.text('QR code'));
    await t.pump();
    expect(find.byKey(const Key('card_barcode')), findsNothing);
    final qr = t.widget<BarcodeWidget>(find.byKey(const Key('card_qr')));
    expect(utf8.decode(qr.data as List<int>), '0419095719373');
    expect(qr.barcode.name, 'QR-Code');

    env.screen.calls.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(env.screen.calls, ['restore', 'awake:false']);
    env.screen.calls.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(env.screen.calls, ['boost', 'awake:true']);

    env.screen.calls.clear();
    await t.pumpWidget(const SizedBox());
    expect(env.screen.calls, ['restore', 'awake:false']);
  });

  screenTest('no_cache_shows_error_with_retry_then_the_card', (t) async {
    final env = await AccountEnv.create(t);
    await env.signIn(1);
    env.h.http.on('GET', '/api/v1/me/card', offline());
    await env.pump(t, initial: Routes.card);
    expect(find.text('Réessayer'), findsOneWidget);
    env.h.http.on('GET', '/api/v1/me/card', cardReply(meCardFixture()));
    await t.tap(find.text('Réessayer'));
    await settle(t);
    expect(find.text('0419 0957 1937 3'), findsOneWidget);
  });

  test('refresh_stores_the_card_and_a_failure_leaves_it_untouched', () async {
    final env = AccountEnv.plain();
    await env.signIn(1);
    env.h.http.on('GET', '/api/v1/me/card', cardReply(meCardFixture()));
    final repo = env.h.container.read(cardRepositoryProvider);
    expect(await repo.refresh(), isA<Refreshed>());
    var row = await env.h.db.cardDao.watchCard().first;
    expect(row?.number, '0419095719373');
    expect(row?.barcodeValue, '0419095719373');

    env.h.http.on('GET', '/api/v1/me/card', offline());
    expect(await repo.refresh(), isA<Failed>());
    row = await env.h.db.cardDao.watchCard().first;
    expect(row?.number, '0419095719373');
  });

  test('signed_out_refresh_is_a_no_op', () async {
    final env = AccountEnv.plain();
    final repo = env.h.container.read(cardRepositoryProvider);
    await repo.refresh();
    expect(env.h.http.calls, isEmpty);
  });
}
