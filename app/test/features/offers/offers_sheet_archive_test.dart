import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/daos/public_dao.dart';
import 'package:supermarket_app/features/offers/ui/flyer_archive_screen.dart';
import 'package:supermarket_app/features/offers/ui/offer_detail_sheet.dart';

import '../../core/db/test_db.dart';
import '../../support/offers_harness.dart';

void main() {
  offersTest('detail sheet shows add-to-list only when the callback is set',
      (tester) async {
    final h = Harness();
    final item = OfferWithProduct(
      offer: offer(1, flyerId: 1, productId: 1),
      product: product(1, name: 'Mangues'),
      category: category(1, 'fruits'),
    );
    await tester.pumpWidget(
      h.app(Scaffold(body: OfferDetailSheet(item: item))),
    );
    await tester.pump();
    expect(find.text('Mangues 1'), findsOneWidget);
    expect(find.text('Ajouter à une liste'), findsNothing);

    var taps = 0;
    await tester.pumpWidget(
      h.app(
        Scaffold(
          body: OfferDetailSheet(item: item, onAddToList: () => taps++),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Ajouter à une liste'));
    await tester.pump();
    await tester.tap(find.text('Ajouter à une liste'));
    expect(taps, 1);
  });

  offersTest('archive lists flyers with tags and refreshes on open',
      (tester) async {
    final h = Harness(start: DateTime(2026, 11, 2));
    h.http.reply('GET', '/flyers', 200, {
      'next': null,
      'previous': null,
      'results': [
        {
          'id': 2,
          'title': 'Ancien',
          'valid_from': '2026-10-01',
          'valid_to': '2026-10-07',
          'cover_image': null,
          'offer_count': 3,
        },
        {
          'id': 3,
          'title': 'Futur',
          'valid_from': '2026-12-01',
          'valid_to': '2026-12-07',
          'cover_image': null,
          'offer_count': 1,
        },
      ],
    });
    await tester.pumpWidget(h.app(const FlyerArchiveScreen()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(h.http.callsTo('/flyers'), hasLength(1));
    expect(find.text('Ancien'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    expect(find.text('3 offres'), findsOneWidget);
    expect(find.text('du 1er au 7 oct.'), findsOneWidget);
  });
}
