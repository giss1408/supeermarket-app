import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'lists_dao.g.dart';

class ListWithItems {
  const ListWithItems({required this.list, required this.items});

  final ShoppingListRow list;
  final List<ListItemRow> items;
}

@DriftAccessor(tables: [ShoppingLists, ListItems])
class ListsDao extends DatabaseAccessor<AppDatabase> with _$ListsDaoMixin {
  ListsDao(super.db);

  Stream<List<ShoppingListRow>> watchLists() => (select(shoppingLists)
        ..where((t) => t.deletedLocally.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Stream<ListWithItems?> watchList(String localId) {
    final query = select(shoppingLists).join([
      leftOuterJoin(
        listItems,
        listItems.listLocalId.equalsExp(shoppingLists.localId),
      ),
    ])
      ..where(shoppingLists.localId.equals(localId))
      ..orderBy([
        OrderingTerm.asc(listItems.checked),
        OrderingTerm.asc(listItems.createdAt),
        OrderingTerm.asc(listItems.localId),
      ]);
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      return ListWithItems(
        list: rows.first.readTable(shoppingLists),
        items: [
          for (final r in rows)
            if (r.readTableOrNull(listItems) case final item?) item,
        ],
      );
    });
  }

  Future<void> upsertList(ShoppingListRow list) =>
      into(shoppingLists).insertOnConflictUpdate(list);

  Future<void> upsertItem(ListItemRow item) =>
      into(listItems).insertOnConflictUpdate(item);

  Future<void> deleteList(String localId) =>
      (delete(shoppingLists)..where((t) => t.localId.equals(localId))).go();

  Future<void> deleteItem(String localId) =>
      (delete(listItems)..where((t) => t.localId.equals(localId))).go();

  Future<ShoppingListRow?> byRemoteId(int remoteId) =>
      (select(shoppingLists)..where((t) => t.remoteId.equals(remoteId)))
          .getSingleOrNull();

  Future<List<ShoppingListRow>> allLists() => select(shoppingLists).get();

  Future<List<ListItemRow>> itemsOf(String listLocalId) =>
      (select(listItems)..where((t) => t.listLocalId.equals(listLocalId)))
          .get();
}
