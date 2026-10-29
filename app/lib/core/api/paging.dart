/// One page of a cursor-paginated list: its items and the cursor of the next
/// page (null on the last page).
typedef PageResult<T> = ({List<T> items, String? next});

/// Extracts the `cursor` query parameter from the API's `next` URL.
///
/// Returns null for a null or empty [next]; throws [FormatException] when a
/// non-empty URL carries no cursor.
String? cursorFromNext(String? next) {
  if (next == null || next.isEmpty) return null;
  final cursor = Uri.parse(next).queryParameters['cursor'];
  if (cursor == null || cursor.isEmpty) {
    throw FormatException('No "cursor" query parameter in next URL', next);
  }
  return cursor;
}

/// Builds a [PageResult] from a generated paginated envelope.
PageResult<T> toPageResult<T>(List<T> results, String? nextUrl) =>
    (items: results, next: cursorFromNext(nextUrl));

/// Follows `next` cursors until the last page and returns all items in order.
///
/// Throws [StateError] once [maxPages] pages were fetched and more remain
/// (safety cap against a server that never ends).
Future<List<T>> fetchAllPages<T>(
  Future<PageResult<T>> Function(String? cursor) fetch, {
  int maxPages = 50,
}) async {
  final all = <T>[];
  String? cursor;
  for (var page = 0; page < maxPages; page++) {
    final result = await fetch(cursor);
    all.addAll(result.items);
    if (result.next == null) return all;
    cursor = result.next;
  }
  throw StateError('More than $maxPages pages; aborting pagination.');
}
