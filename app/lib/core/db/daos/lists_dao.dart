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

  Future<ShoppingListRow?> listByLocalId(String localId) => (select(
        shoppingLists,
      )..where((t) => t.localId.equals(localId)))
          .getSingleOrNull();

  Future<ListItemRow?> itemByLocalId(String localId) =>
      (select(listItems)..where((t) => t.localId.equals(localId)))
          .getSingleOrNull();

  /// Stores the server identity of a list (create result or adoption).
  Future<void> setListServerIds(
    String localId, {
    required int remoteId,
    required String? serverUpdatedAt,
  }) =>
      (update(shoppingLists)..where((t) => t.localId.equals(localId))).write(
        ShoppingListsCompanion(
          remoteId: Value(remoteId),
          serverUpdatedAt: Value(serverUpdatedAt),
        ),
      );

  Future<void> setItemRemoteId(String localId, int remoteId) =>
      (update(listItems)..where((t) => t.localId.equals(localId)))
          .write(ListItemsCompanion(remoteId: Value(remoteId)));

  Future<void> setListDirty(String localId, {required bool dirty}) =>
      (update(shoppingLists)..where((t) => t.localId.equals(localId)))
          .write(ShoppingListsCompanion(dirty: Value(dirty)));

  Future<void> setItemDirty(String localId, {required bool dirty}) =>
      (update(listItems)..where((t) => t.localId.equals(localId)))
          .write(ListItemsCompanion(dirty: Value(dirty)));

  Future<void> setListServerUpdatedAt(String localId, String? value) =>
      (update(shoppingLists)..where((t) => t.localId.equals(localId)))
          .write(ShoppingListsCompanion(serverUpdatedAt: Value(value)));

  Future<void> setListDeletedLocally(
    String localId, {
    required bool deleted,
  }) =>
      (update(shoppingLists)..where((t) => t.localId.equals(localId)))
          .write(ShoppingListsCompanion(deletedLocally: Value(deleted)));
}
