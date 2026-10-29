import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'card_dao.g.dart';

@DriftAccessor(tables: [LoyaltyCard])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  Future<void> setCard(String number, String barcodeValue) =>
      into(loyaltyCard).insertOnConflictUpdate(
        LoyaltyCardCompanion.insert(
          id: const Value(1),
          number: number,
          barcodeValue: barcodeValue,
        ),
      );

  Stream<LoyaltyCardRow?> watchCard() =>
      select(loyaltyCard).watchSingleOrNull();
}
