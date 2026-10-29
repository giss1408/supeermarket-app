import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';

import 'test_db.dart';

void main() {
  test('schemaVersion is 1', () {
    expect(createTestDb().schemaVersion, 1);
  });

  test('row and companion classes carry the expected names', () {
    final rows = <Object>[
      category(1, 's'),
      product(1),
      flyer(1),
      offer(1, flyerId: 1, productId: 1),
      store(1),
      const OpeningHoursRow(storeId: 1, weekday: 0, opens: 'a', closes: 'b'),
      const PaymentMethodRow(
          provider: 'wave',
          phoneNumber: '',
          displayName: '',
          instructions: '',
          updatedAt: ''),
      shoppingList('a'),
      listItem('i', 'a'),
      const LoyaltyCardRow(id: 1, number: 'n', barcodeValue: 'b'),
      const OutboxOpRow(
          id: 1,
          opType: 'o',
          listLocalId: 'l',
          itemLocalId: null,
          payloadJson: '{}',
          state: 'pending',
          attempts: 0,
          lastError: null,
          createdAt: ''),
      const SyncMetaRow(key: 'k', value: 'v'),
    ];
    expect(rows.map((r) => r.runtimeType.toString()), [
      'CategoryRow',
      'ProductRow',
      'FlyerRow',
      'OfferRow',
      'StoreRow',
      'OpeningHoursRow',
      'PaymentMethodRow',
      'ShoppingListRow',
      'ListItemRow',
      'LoyaltyCardRow',
      'OutboxOpRow',
      'SyncMetaRow',
    ]);
    expect(const OutboxOpsCompanion(id: Value(1)).id.value, 1);
  });
}
