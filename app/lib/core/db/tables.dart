import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get slug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProductRow')
class Products extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get categoryId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FlyerRow')
class Flyers extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();

  /// ISO date `YYYY-MM-DD`.
  TextColumn get validFrom => text()();
  TextColumn get validTo => text()();
  TextColumn get coverImageUrl => text().nullable()();
  IntColumn get offerCount => integer().withDefault(const Constant(0))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OfferRow')
class Offers extends Table {
  IntColumn get id => integer()();
  IntColumn get flyerId =>
      integer().references(Flyers, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();

  /// Decimal string such as `"1500.00"` (never REAL).
  TextColumn get price => text()();
  TextColumn get oldPrice => text().nullable()();
  TextColumn get badgeText => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get validFrom => text().nullable()();
  TextColumn get validTo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoreRow')
class Stores extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  TextColumn get city => text()();
  TextColumn get postcode => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get phone => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OpeningHoursRow')
class OpeningHours extends Table {
  IntColumn get storeId =>
      integer().references(Stores, #id, onDelete: KeyAction.cascade)();

  /// 0 = Monday.
  IntColumn get weekday => integer()();

  /// `HH:MM`.
  TextColumn get opens => text()();
  TextColumn get closes => text()();

  @override
  Set<Column> get primaryKey => {storeId, weekday};
}

@DataClassName('PaymentMethodRow')
class PaymentMethods extends Table {
  /// `wave | orange_money | mtn_momo`.
  TextColumn get provider => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get displayName => text()();
  TextColumn get instructions => text()();

  /// Server ISO timestamp as received.
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {provider};
}

@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  /// UUID v4.
  TextColumn get localId => text()();
  IntColumn get remoteId => integer().nullable().unique()();
  TextColumn get name => text()();

  /// Server timestamp as received.
  TextColumn get serverUpdatedAt => text().nullable()();

  /// ISO, device time, only for local ordering.
  TextColumn get createdAt => text()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {localId};
}

@DataClassName('ListItemRow')
class ListItems extends Table {
  TextColumn get localId => text()();
  TextColumn get listLocalId =>
      text().references(ShoppingLists, #localId, onDelete: KeyAction.cascade)();
  IntColumn get remoteId => integer().nullable()();
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text().nullable()();
  TextColumn get productUnit => text().nullable()();
  TextColumn get productImageUrl => text().nullable()();

  /// Dart name `itemText` because `text` clashes with `Table.text()`; the SQL
  /// column is `text`.
  TextColumn get itemText =>
      text().named('text').withDefault(const Constant(''))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// ISO, for ordering.
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {localId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {listLocalId, remoteId},
      ];

  @override
  List<String> get customConstraints => [
        "CHECK (product_id IS NOT NULL OR \"text\" != '')",
        'CHECK (quantity BETWEEN 1 AND 999)',
      ];
}

@DataClassName('LoyaltyCardRow')
class LoyaltyCard extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get number => text()();
  TextColumn get barcodeValue => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('OutboxOpRow')
class OutboxOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opType => text()();
  TextColumn get listLocalId => text()();
  TextColumn get itemLocalId => text().nullable()();
  TextColumn get payloadJson => text()();

  /// `pending | inFlight | failed`.
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  List<String> get customConstraints =>
      ["CHECK (state IN ('pending', 'inFlight', 'failed'))"];
}

@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
