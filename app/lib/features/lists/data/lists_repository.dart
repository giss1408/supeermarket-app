import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/sync/outbox_repository.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/util/clock.dart';

const maxListNameLength = 100;
const _uuid = Uuid();

/// Local-first shopping lists: every mutation writes the rows and the outbox
/// op in one transaction and returns at once; the network is never awaited.
class ListsRepository {
  ListsRepository({
    required AppDatabase db,
    required Clock clock,
    void Function()? onMutated,
  })  : _db = db,
        _clock = clock,
        _outbox = OutboxRepository(db, clock),
        _onMutated = onMutated;

  final AppDatabase _db;
  final Clock _clock;
  final OutboxRepository _outbox;
  final void Function()? _onMutated;

  String _now() => _clock().toUtc().toIso8601String();

  /// The server trims names/texts, so they are trimmed here too: what is
  /// queued is exactly what the server stores (needed to recognise a create
  /// that already reached it).
  String _validName(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError.value(name, 'name', 'must not be blank');
    if (n.length > maxListNameLength) {
      throw ArgumentError.value(name, 'name', 'longer than $maxListNameLength');
    }
    return n;
  }

  void _validQuantity(int q) {
    if (q < 1 || q > 999) {
      throw ArgumentError.value(q, 'quantity', 'must be between 1 and 999');
    }
  }

  Stream<List<ShoppingListRow>> watchLists() => _db.listsDao.watchLists();

  Stream<ListWithItems?> watchList(String localId) =>
      _db.listsDao.watchList(localId);

  Future<int> pendingCount() => _db.outboxDao.pendingCount();

  Stream<int> watchPendingCount() => _db.outboxDao.watchPendingCount();

  Future<String> createList(String name) async {
    final n = _validName(name);
    final id = _uuid.v4();
    await _outbox.createList(ShoppingListRow(
      localId: id,
      remoteId: null,
      name: n,
      serverUpdatedAt: null,
      createdAt: _now(),
      dirty: true,
      deletedLocally: false,
    ));
    _onMutated?.call();
    return id;
  }

  Future<void> renameList(String localId, String name) async {
    final n = _validName(name);
    await _outbox.renameList(localId, n);
    _onMutated?.call();
  }

  Future<void> deleteList(String localId) async {
    await _outbox.deleteList(localId);
    _onMutated?.call();
  }

  Future<String> addItem(
    String listLocalId, {
    int? productId,
    String? productName,
    String? productUnit,
    String? productImageUrl,
    String text = '',
    int quantity = 1,
  }) async {
    final t = text.trim();
    if (productId == null && t.isEmpty) {
      throw ArgumentError('An item needs a product or a text');
    }
    _validQuantity(quantity);
    final id = _uuid.v4();
    await _outbox.addItem(ListItemRow(
      localId: id,
      listLocalId: listLocalId,
      remoteId: null,
      productId: productId,
      productName: productName,
      productUnit: productUnit,
      productImageUrl: productImageUrl,
      itemText: t,
      quantity: quantity,
      checked: false,
      dirty: true,
      createdAt: _now(),
    ));
    _onMutated?.call();
    return id;
  }

  Future<void> updateItem(
    String itemLocalId, {
    int? quantity,
    bool? checked,
    String? text,
  }) async {
    if (quantity != null) _validQuantity(quantity);
    final t = text?.trim();
    if (t != null && t.isEmpty) {
      final item = await _db.listsDao.itemByLocalId(itemLocalId);
      if (item != null && item.productId == null) {
        throw ArgumentError('An item needs a product or a text');
      }
    }
    await _outbox.updateItem(
      itemLocalId,
      quantity: quantity,
      checked: checked,
      text: t,
    );
    _onMutated?.call();
  }

  Future<void> deleteItem(String itemLocalId) async {
    await _outbox.deleteItem(itemLocalId);
    _onMutated?.call();
  }
}

final listsRepositoryProvider = Provider<ListsRepository>(
  (ref) => ListsRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    onMutated: () => ref.read(syncCoordinatorProvider).requestSync(),
  ),
);
