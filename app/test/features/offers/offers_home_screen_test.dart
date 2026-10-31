import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/money/xof.dart';
import 'package:supermarket_app/core/ui/offline_banner.dart';
import 'package:supermarket_app/core/ui/skeleton.dart';
import 'package:supermarket_app/features/offers/ui/offer_card.dart';
import 'package:supermarket_app/features/offers/ui/offers_home_screen.dart';

import '../../support/fake_http.dart';
import '../../support/offers_harness.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder cards() => find.byType(OfferCard);

void main() {
  offersTest('skeleton, then grid with header, price and badge',
      (tester) async {
    final h = Harness();
    final gate = Completer<void>();
    h.http.on('GET', '/flyers/current', (_, __) async {
      await gate.future;
      return FakeResponse(200, fixture('flyers_current'));
    });
    await tester.pumpWidget(h.app(const OffersHomeScreen()));
    await settle(tester);
    expect(find.byType(Skeleton), findsWidgets);
    expect(cards(), findsNothing);

    gate.complete();
    await settle(tester);
    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Valable du 29 oct. au 4 nov.'), findsOneWidget);
    expect(find.text(formatXof('750.00')), findsOneWidget);
    expect(find.text('-25%'), findsOneWidget);
    expect(find.text('Anciens prospectus'), findsOneWidget);
  });

  offersTest('category chip and accent-insensitive search filter the grid',
      (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app(const OffersHomeScreen()));
    await settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fruits et légumes'));
    await settle(tester);
    expect(cards(), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tout'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.text('Café moulu'), findsOneWidget);
    expect(cards(), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.text('Aucune offre ne correspond'), findsOneWidget);
  });

  offersTest('server 404 shows the empty state', (tester) async {
    final h = Harness();
    h.http.reply('GET', '/flyers/current', 404, errorBody('not_found'));
    await tester.pumpWidget(h.app(const OffersHomeScreen()));
    await settle(tester);
    expect(find.text('Aucun prospectus en cours'), findsOneWidget);
  });

  offersTest('cached data plus a network error shows the offline banner',
      (tester) async {
    final h = Harness();
    await tester.runAsync(() => h.repo.refreshCurrentFlyer());
    h.now = h.now.add(const Duration(hours: 1));
    h.http.on('GET', '/flyers/current', offline());
    await tester.pumpWidget(h.app(const OffersHomeScreen()));
    await settle(tester);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(cards(), findsWidgets);
  });

  offersTest('no overflow at 320dp and text scale 2.0', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    final h = Harness(start: DateTime(2026, 11, 5));
    await tester.pumpWidget(h.app(const OffersHomeScreen(), textScale: 2.0));
    await settle(tester);
    expect(tester.getSize(find.byType(Scaffold).first).width, 320);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(cards(), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
