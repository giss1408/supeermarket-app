import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';
import 'like_escape.dart';

part 'public_dao.g.dart';

class OfferWithProduct {
  const OfferWithProduct({
    required this.offer,
    required this.product,
    this.category,
  });

  final OfferRow offer;
  final ProductRow product;
  final CategoryRow? category;
}

@DriftAccessor(tables: [Categories, Products, Flyers, Offers])
class PublicDao extends DatabaseAccessor<AppDatabase> with _$PublicDaoMixin {
  PublicDao(super.db);

  /// Atomically swaps in a new current flyer. Any failure rolls everything
  /// back, so the previous current flyer and its offers stay intact.
  Future<void> replaceCurrentFlyer(
    FlyerRow flyer,
    List<ProductRow> productRows,
    List<OfferRow> offerRows,
  ) =>
      transaction(() async {
        await batch((b) => b.insertAllOnConflictUpdate(products, productRows));

        final others = await (select(flyers)
              ..where((t) => t.id.equals(flyer.id).not()))
            .get();
        final otherIds = others.map((f) => f.id).toList();
        await (delete(offers)..where((t) => t.flyerId.isIn(otherIds))).go();
        await (update(flyers)..where((t) => t.id.equals(flyer.id).not()))
            .write(const FlyersCompanion(isCurrent: Value(false)));

        await into(flyers)
            .insertOnConflictUpdate(flyer.copyWith(isCurrent: true));
        await (delete(offers)..where((t) => t.flyerId.equals(flyer.id))).go();
        // Plain inserts (not upserts): a duplicate offer id must fail.
        for (final o in offerRows) {
          await into(offers).insert(o);
        }
      });

  Future<void> upsertCategories(List<CategoryRow> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(categories, rows));

  Future<void> upsertArchiveFlyers(List<FlyerRow> rows) =>
      transaction(() async {
        for (final f in rows) {
          final existing = await (select(flyers)
                ..where((t) => t.id.equals(f.id)))
              .getSingleOrNull();
          await into(flyers).insertOnConflictUpdate(
            f.copyWith(isCurrent: existing?.isCurrent ?? false),
          );
        }
      });

  Stream<FlyerRow?> watchCurrentFlyer() => (select(flyers)
        ..where((t) => t.isCurrent.equals(true))
        ..limit(1))
      .watchSingleOrNull();

  Stream<List<OfferWithProduct>> watchCurrentOffers({
    String? categorySlug,
    String query = '',
  }) {
    final q = select(offers).join([
      innerJoin(flyers, flyers.id.equalsExp(offers.flyerId)),
      innerJoin(products, products.id.equalsExp(offers.productId)),
      leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
    ])
      ..where(flyers.isCurrent.equals(true))
      ..orderBy([
        OrderingTerm.asc(offers.sortOrder),
        OrderingTerm.asc(offers.id),
      ]);
    if (categorySlug != null) {
      q.where(categories.slug.equals(categorySlug));
    }
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      q.where(
        containsLiteral(products.name, trimmed) |
            containsLiteral(offers.badgeText, trimmed),
      );
    }
    return q.watch().map(
          (rows) => [
            for (final r in rows)
              OfferWithProduct(
                offer: r.readTable(offers),
                product: r.readTable(products),
                category: r.readTableOrNull(categories),
              ),
          ],
        );
  }

  Stream<List<FlyerRow>> watchArchive() => (select(flyers)
        ..where((t) => t.isCurrent.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.validFrom)]))
      .watch();

  Stream<List<CategoryRow>> watchCategories() => (select(categories)
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();
}
