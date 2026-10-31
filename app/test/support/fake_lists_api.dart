import 'package:supermarket_app/core/api/paging.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/sync/lists_api.dart';
import 'package:supermarket_app/core/sync/server_time.dart';

ApiError apiError(int status) =>
    ApiError(code: 'e$status', status: status, fields: const {});

class _Item {
  _Item(this.id, this.productId, this.text, this.quantity, this.checked);
  final int id;
  final int? productId;
  String text;
  int quantity;
  bool checked;
}

class _List {
  _List(this.id, this.name, this.updatedAt);
  final int id;
  String name;
  String updatedAt;
  final items = <_Item>[];
}

class _Failure {
  _Failure(this.error, this.applyFirst);
  final AppError error;
  final bool applyFirst;
}

/// A tiny in-memory server behind the [ListsApi] interface. Its stamps are
/// strictly increasing SERVER times (one second apart, from a fixed base),
/// independent of any device clock. Records every call.
class FakeListsApi implements ListsApi {
  final calls = <String>[];
  final _lists = <int, _List>{};
  final _failures = <String, List<_Failure>>{};
  int _nextListId = 1;
  int _nextItemId = 1;
  int _tick = 0;
  int pageSize = 100;
  int _active = 0;
  int maxConcurrent = 0;

  /// Awaited at the start of every call (before the failure/answer logic).
  Future<void> Function(String call)? onCall;

  static final _base = DateTime.utc(2026, 10, 29, 12);

  String stamp([int? tick]) => formatServerInstant(
        _base.add(Duration(seconds: tick ?? _tick)),
      );

  String _bump() {
    _tick += 10;
    return stamp();
  }

  List<String> get writes => [
        for (final c in calls)
          if (!c.startsWith('listLists') &&
              !c.startsWith('getList') &&
              c != 'allListIds')
            c,
      ];

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  int get listCount => _lists.length;
  List<String> listNames() => [for (final l in _lists.values) l.name];
  int itemCount(int listId) => _lists[listId]?.items.length ?? 0;
  String latestStamp() => stamp();

  /// The next call of [method] fails; with [applyFirst] the request reached
  /// the server (its effect happened) but the answer was lost.
  void failNext(String method, AppError error, {bool applyFirst = false}) =>
      (_failures[method] ??= []).add(_Failure(error, applyFirst));

  int seedList(String name) {
    final l = _List(_nextListId++, name, _bump());
    _lists[l.id] = l;
    return l.id;
  }

  int seedItem(
    int listId, {
    int? productId,
    String text = '',
    int quantity = 1,
    bool checked = false,
  }) {
    final l = _lists[listId]!;
    final i = _Item(_nextItemId++, productId, text, quantity, checked);
    l.items.add(i);
    l.updatedAt = _bump();
    return i.id;
  }

  void renameOnServer(int id, String name) {
    _lists[id]!
      ..name = name
      ..updatedAt = _bump();
  }

  void setItemOnServer(int listId, int itemId, {bool? checked, int? quantity}) {
    final l = _lists[listId]!;
    final i = l.items.firstWhere((i) => i.id == itemId);
    if (checked != null) i.checked = checked;
    if (quantity != null) i.quantity = quantity;
    l.updatedAt = _bump();
  }

  void dropListOnServer(int id) => _lists.remove(id);

  void dropItemOnServer(int listId, int itemId) {
    _lists[listId]!.items.removeWhere((i) => i.id == itemId);
    _lists[listId]!.updatedAt = _bump();
  }

  Future<T> _do<T>(String method, String call, T Function() action) async {
    calls.add(call);
    _active++;
    if (_active > maxConcurrent) maxConcurrent = _active;
    try {
      await onCall?.call(call);
      await Future<void>.delayed(Duration.zero);
      final queue = _failures[method];
      if (queue != null && queue.isNotEmpty) {
        final f = queue.removeAt(0);
        if (f.applyFirst) action();
        throw f.error;
      }
      return action();
    } finally {
      _active--;
    }
  }

  _List _list(int id) {
    final l = _lists[id];
    if (l == null) throw apiError(404);
    return l;
  }

  RemoteItem _item(_Item i) => RemoteItem(
        id: i.id,
        productId: i.productId,
        text: i.text,
        quantity: i.quantity,
        checked: i.checked,
      );

  RemoteList _summary(_List l) =>
      RemoteList(id: l.id, name: l.name, updatedAt: l.updatedAt);

  @override
  Future<RemoteList> createList(String name) =>
      _do('createList', 'createList:$name', () {
        final id = seedList(name);
        return _summary(_lists[id]!);
      });

  @override
  Future<void> renameList(int id, String name) =>
      _do('renameList', 'renameList:$id:$name', () {
        _list(id);
        renameOnServer(id, name);
      });

  @override
  Future<void> deleteList(int id) => _do('deleteList', 'deleteList:$id', () {
        _list(id);
        _lists.remove(id);
      });

  @override
  Future<RemoteItem> createItem(int listId, ItemPayload p) => _do(
        'createItem',
        'createItem:$listId:${p.productId ?? p.text}:${p.quantity}',
        () {
          _list(listId);
          final id = seedItem(
            listId,
            productId: p.productId,
            text: p.text ?? '',
            quantity: p.quantity ?? 1,
            checked: p.checked ?? false,
          );
          return _item(_lists[listId]!.items.firstWhere((i) => i.id == id));
        },
      );

  @override
  Future<void> updateItem(int listId, int itemId, ItemPayload p) => _do(
        'updateItem',
        'updateItem:$listId:$itemId:'
            '${p.quantity ?? '-'}:${p.checked ?? '-'}:${p.text ?? '-'}',
        () {
          final l = _list(listId);
          final i = l.items.where((i) => i.id == itemId).firstOrNull;
          if (i == null) throw apiError(404);
          if (p.quantity != null) i.quantity = p.quantity!;
          if (p.checked != null) i.checked = p.checked!;
          if (p.text != null) i.text = p.text!;
          l.updatedAt = _bump();
        },
      );

  @override
  Future<void> deleteItem(int listId, int itemId) => _do(
        'deleteItem',
        'deleteItem:$listId:$itemId',
        () {
          final l = _list(listId);
          if (!l.items.any((i) => i.id == itemId)) throw apiError(404);
          l.items.removeWhere((i) => i.id == itemId);
          l.updatedAt = _bump();
        },
      );

  @override
  Future<PageResult<RemoteListSummary>> listLists({
    String? updatedSince,
    String? cursor,
  }) =>
      _do('listLists', 'listLists:${updatedSince ?? '-'}:${cursor ?? '-'}', () {
        final since =
            updatedSince == null ? null : parseServerInstant(updatedSince);
        final all = [
          for (final l in _lists.values)
            if (since == null || parseServerInstant(l.updatedAt).isAfter(since))
              l,
        ]..sort((a, b) => a.id.compareTo(b.id));
        final start = int.parse(cursor ?? '0');
        final page = all.skip(start).take(pageSize).toList();
        final more = start + pageSize < all.length;
        return (
          items: [for (final l in page) _summary(l)],
          next: more ? '${start + pageSize}' : null,
        );
      });

  @override
  Future<RemoteListDetail> getList(int id) => _do('getList', 'getList:$id', () {
        final l = _list(id);
        return RemoteListDetail(
          list: _summary(l),
          items: [for (final i in l.items) _item(i)],
        );
      });

  @override
  Future<Set<int>> allListIds() =>
      _do('allListIds', 'allListIds', () => _lists.keys.toSet());
}
