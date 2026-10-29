import 'package:drift/drift.dart';

import 'daos/card_dao.dart';
import 'daos/lists_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/payment_dao.dart';
import 'daos/public_dao.dart';
import 'daos/stores_dao.dart';
import 'daos/sync_meta_dao.dart';
import 'daos/sync_meta_keys.dart' as keys;
import 'tables.dart';

export 'daos/lists_dao.dart' show ListWithItems;
export 'daos/public_dao.dart' show OfferWithProduct;
export 'daos/stores_dao.dart' show StoreWithHours;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Products,
    Flyers,
    Offers,
    Stores,
    OpeningHours,
    PaymentMethods,
    ShoppingLists,
    ListItems,
    LoyaltyCard,
    OutboxOps,
    SyncMeta,
  ],
  daos: [
    PublicDao,
    StoresDao,
    PaymentDao,
    ListsDao,
    CardDao,
    SyncMetaDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  late final OutboxDao outboxDao = OutboxDao(this);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Removes everything that belongs to the signed-in user, keeping the
  /// cached public data and its freshness markers.
  Future<void> wipeUserData() => transaction(() async {
        await delete(outboxOps).go();
        await delete(listItems).go();
        await delete(shoppingLists).go();
        await delete(loyaltyCard).go();
        await (delete(syncMeta)
              ..where((t) =>
                  t.key.isIn(const [keys.listsLastPull, keys.lastUserId])))
            .go();
      });
}
