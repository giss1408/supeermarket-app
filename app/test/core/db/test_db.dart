import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';

/// In-memory database, closed automatically at the end of the test.
AppDatabase createTestDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

FlyerRow flyer(int id,
        {String validFrom = '2026-10-29', bool current = false}) =>
    FlyerRow(
      id: id,
      title: 'Prospectus $id',
      validFrom: validFrom,
      validTo: '2026-11-04',
      coverImageUrl: null,
      offerCount: 0,
      isCurrent: current,
    );

ProductRow product(int id, {String name = 'Produit', int? categoryId}) =>
    ProductRow(
      id: id,
      name: '$name $id',
      description: '',
      unit: '1 kg',
      imageUrl: null,
      categoryId: categoryId,
    );

OfferRow offer(
  int id, {
  required int flyerId,
  required int productId,
  int sortOrder = 0,
  String badge = '',
}) =>
    OfferRow(
      id: id,
      flyerId: flyerId,
      productId: productId,
      price: '1500.00',
      oldPrice: null,
      badgeText: badge,
      sortOrder: sortOrder,
      validFrom: null,
      validTo: null,
    );

CategoryRow category(int id, String slug, {int sortOrder = 0}) => CategoryRow(
      id: id,
      name: 'Cat $slug',
      slug: slug,
      sortOrder: sortOrder,
    );

StoreRow store(int id, {String name = 'Magasin', String city = 'Abidjan'}) =>
    StoreRow(
      id: id,
      name: '$name $id',
      address: 'Rue $id',
      city: city,
      postcode: '0$id',
      latitude: 5.3,
      longitude: -4.0,
      phone: '',
    );

ShoppingListRow shoppingList(
  String localId, {
  int? remoteId,
  String createdAt = '2026-10-29T10:00:00Z',
}) =>
    ShoppingListRow(
      localId: localId,
      remoteId: remoteId,
      name: 'Courses $localId',
      serverUpdatedAt: null,
      createdAt: createdAt,
      dirty: false,
      deletedLocally: false,
    );

ListItemRow listItem(
  String localId,
  String listLocalId, {
  int quantity = 1,
  int? productId,
  String text = 'Pain',
  bool checked = false,
  String createdAt = '2026-10-29T10:00:00Z',
}) =>
    ListItemRow(
      localId: localId,
      listLocalId: listLocalId,
      remoteId: null,
      productId: productId,
      productName: null,
      productUnit: null,
      productImageUrl: null,
      itemText: text,
      quantity: quantity,
      checked: checked,
      dirty: false,
      createdAt: createdAt,
    );

OutboxOpsCompanion op(String type) => OutboxOpsCompanion.insert(
      opType: type,
      listLocalId: 'l1',
      payloadJson: '{}',
      createdAt: '2026-10-29T10:00:00Z',
    );
