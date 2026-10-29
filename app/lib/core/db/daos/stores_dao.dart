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

  Future<void> replaceStores(
    List<StoreRow> storeRows,
    List<OpeningHoursRow> hourRows,
  ) =>
      transaction(() async {
        await delete(openingHours).go();
        await delete(stores).go();
        await batch((b) {
          b.insertAll(stores, storeRows);
          b.insertAll(openingHours, hourRows);
        });
      });

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
