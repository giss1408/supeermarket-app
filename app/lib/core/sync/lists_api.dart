import 'package:api_client/api_client.dart' as gen;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../api/paging.dart';
import '../errors/error_mapper.dart';

/// A shopping list as the server describes it. [updatedAt] is the SERVER
/// timestamp as an ISO-8601 UTC string; it is only ever compared with other
/// server values.
class RemoteList {
  const RemoteList({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.createdAt,
  });

  final int id;
  final String name;
  final String updatedAt;
  final String? createdAt;
}

typedef RemoteListSummary = RemoteList;

class RemoteItem {
  const RemoteItem({
    required this.id,
    required this.text,
    required this.quantity,
    required this.checked,
    this.productId,
    this.productName,
    this.productUnit,
    this.productImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? productId;
  final String? productName;
  final String? productUnit;
  final String? productImageUrl;
  final String text;
  final int quantity;
  final bool checked;
  final String? createdAt;
  final String? updatedAt;
}

class RemoteListDetail {
  const RemoteListDetail({required this.list, required this.items});

  final RemoteList list;
  final List<RemoteItem> items;
}

/// Fields of an item request. Null fields are not sent (PATCH semantics).
class ItemPayload {
  const ItemPayload({this.productId, this.text, this.quantity, this.checked});

  final int? productId;
  final String? text;
  final int? quantity;
  final bool? checked;
}

/// Server access of the sync engine. Abstract so tests can script it; errors
/// are thrown as mapped `AppError`s.
abstract class ListsApi {
  Future<RemoteList> createList(String name);
  Future<void> renameList(int id, String name);
  Future<void> deleteList(int id);
  Future<RemoteItem> createItem(int listId, ItemPayload p);

  /// PATCH: only the fields present in [p].
  Future<void> updateItem(int listId, int itemId, ItemPayload p);
  Future<void> deleteItem(int listId, int itemId);
  Future<PageResult<RemoteListSummary>> listLists({
    String? updatedSince,
    String? cursor,
  });
  Future<RemoteListDetail> getList(int id);

  /// Ids of every list the server has (all pages, capped at 50).
  Future<Set<int>> allListIds();
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

RemoteList _toList(int id, String name, DateTime created, DateTime updated) =>
    RemoteList(
      id: id,
      name: name,
      updatedAt: _iso(updated),
      createdAt: _iso(created),
    );

RemoteItem _toItem(gen.ListItem i) => RemoteItem(
      id: i.id,
      productId: i.product?.id,
      productName: i.product?.name,
      productUnit: i.product?.unit,
      productImageUrl: i.product?.image,
      text: i.text ?? '',
      quantity: i.quantity ?? 1,
      checked: i.checked ?? false,
      createdAt: _iso(i.createdAt),
      updatedAt: _iso(i.updatedAt),
    );

RemoteListDetail _toDetail(gen.ShoppingListDetail d) => RemoteListDetail(
      list: _toList(d.id, d.name, d.createdAt, d.updatedAt),
      items: [for (final i in d.items) _toItem(i)],
    );

/// Thin wrapper over the generated client.
class GeneratedListsApi implements ListsApi {
  GeneratedListsApi(this._api);

  final gen.ListsApi _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<RemoteList> createList(String name) => _guard(() async {
        final r = await _api.listsCreate(
          shoppingListDetailRequest: gen.ShoppingListDetailRequest(name: name),
        );
        final d = r.data!;
        return _toList(d.id, d.name, d.createdAt, d.updatedAt);
      });

  @override
  Future<void> renameList(int id, String name) => _guard(
        () => _api.listsPartialUpdate(
          id: id,
          patchedShoppingListDetailRequest:
              gen.PatchedShoppingListDetailRequest(name: name),
        ),
      );

  @override
  Future<void> deleteList(int id) => _guard(() => _api.listsDestroy(id: id));

  @override
  Future<RemoteItem> createItem(int listId, ItemPayload p) => _guard(() async {
        final r = await _api.listsItemsCreate(
          listId: listId,
          listItemRequest: gen.ListItemRequest(
            product: p.productId,
            text: p.text,
            quantity: p.quantity,
            checked: p.checked,
          ),
        );
        return _toItem(r.data!);
      });

  @override
  Future<void> updateItem(int listId, int itemId, ItemPayload p) => _guard(
        () => _api.listsItemsPartialUpdate(
          listId: listId,
          itemId: itemId,
          patchedListItemRequest: gen.PatchedListItemRequest(
            product: p.productId,
            text: p.text,
            quantity: p.quantity,
            checked: p.checked,
          ),
        ),
      );

  @override
  Future<void> deleteItem(int listId, int itemId) => _guard(
        () => _api.listsItemsDestroy(listId: listId, itemId: itemId),
      );

  @override
  Future<PageResult<RemoteListSummary>> listLists({
    String? updatedSince,
    String? cursor,
  }) =>
      _guard(() async {
        final r = await _api.listsList(
          cursor: cursor,
          updatedSince:
              updatedSince == null ? null : DateTime.parse(updatedSince),
        );
        final d = r.data!;
        return toPageResult([
          for (final l in d.results)
            _toList(l.id, l.name, l.createdAt, l.updatedAt),
        ], d.next);
      });

  @override
  Future<RemoteListDetail> getList(int id) => _guard(() async {
        final r = await _api.listsRetrieve(id: id);
        return _toDetail(r.data!);
      });

  @override
  Future<Set<int>> allListIds() async {
    final all = await fetchAllPages<RemoteList>((c) => listLists(cursor: c));
    return {for (final l in all) l.id};
  }
}

final listsApiProvider = Provider<ListsApi>(
  (ref) => GeneratedListsApi(ref.watch(apiClientProvider).getListsApi()),
);
