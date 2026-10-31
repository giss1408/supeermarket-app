import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';
import '../../util/search_fold.dart';
import 'like_escape.dart';

part 'stores_dao.g.dart';

class StoreWithHours {
  const StoreWithHours({required this.store, required this.hours});

  final StoreRow store;
  final List<OpeningHoursRow> hours;
}

@DriftAccessor(tables: [Stores, OpeningHours])
class StoresDao extends DatabaseAccessor<AppDatabase> with _$StoresDaoMixin {
  StoresDao(super.db);

  /// Replaces the store list in one transaction. Stores missing from
  /// [storeRows] are deleted with their hours. Hours are replaced only for
  /// [hoursRefreshedFor] (default: every store); the cached hours of other
  /// stores (whose detail fetch failed) are kept.
  Future<void> replaceStores(
    List<StoreRow> storeRows,
    List<OpeningHoursRow> hourRows, {
    Set<int>? hoursRefreshedFor,
  }) =>
      transaction(() async {
        final ids = {for (final s in storeRows) s.id};
        final refreshed = hoursRefreshedFor ?? ids;
        await (delete(openingHours)..where((t) => t.storeId.isNotIn(ids))).go();
        await (delete(stores)..where((t) => t.id.isNotIn(ids))).go();
        await (delete(openingHours)..where((t) => t.storeId.isIn(refreshed)))
            .go();
        for (final s in storeRows) {
          await into(stores).insertOnConflictUpdate(s);
        }
        await batch((b) => b.insertAll(openingHours, hourRows));
      });

  /// Inserts or updates one store and replaces ITS opening hours only.
  Future<void> upsertStoreWithHours(
    StoreRow storeRow,
    List<OpeningHoursRow> hourRows,
  ) =>
      transaction(() async {
        await into(stores).insertOnConflictUpdate(storeRow);
        await (delete(openingHours)
              ..where((t) => t.storeId.equals(storeRow.id)))
            .go();
        await batch((b) => b.insertAll(openingHours, hourRows));
      });

  /// Opening hours of every store (for open/closed badges in the list).
  Stream<List<OpeningHoursRow>> watchAllHours() => select(openingHours).watch();

  Stream<List<StoreRow>> watchStores({String query = ''}) {
    final q = select(stores)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (foldSearch(query).trim().isNotEmpty) {
      q.where(
        (t) =>
            containsFolded(t.name, query)! |
            containsFolded(t.city, query)! |
            containsFolded(t.postcode, query)! |
            containsFolded(t.address, query)!,
      );
    }
    return q.watch();
  }

  Stream<StoreWithHours?> watchStore(int id) {
    final q = select(stores).join([
      leftOuterJoin(openingHours, openingHours.storeId.equalsExp(stores.id)),
    ])
      ..where(stores.id.equals(id))
      ..orderBy([OrderingTerm.asc(openingHours.weekday)]);
    return q.watch().map((rows) {
      if (rows.isEmpty) return null;
      return StoreWithHours(
        store: rows.first.readTable(stores),
        hours: [
          for (final r in rows)
            if (r.readTableOrNull(openingHours) case final h?) h,
        ],
      );
    });
  }
}
