import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/api/paging.dart';

void main() {
  group('cursorFromNext', () {
    test('extracts and decodes the cursor', () {
      expect(
        cursorFromNext('https://host/api/v1/offers?cursor=abc%3D&page=1'),
        'abc=',
      );
    });

    test('null and empty give null', () {
      expect(cursorFromNext(null), isNull);
      expect(cursorFromNext(''), isNull);
    });

    test('throws FormatException without a cursor', () {
      expect(
        () => cursorFromNext('https://host/api/v1/offers?page=2'),
        throwsFormatException,
      );
    });
  });

  group('fetchAllPages', () {
    test('follows next to the end, in order', () async {
      final seen = <String?>[];
      final items = await fetchAllPages<int>((cursor) async {
        seen.add(cursor);
        return switch (cursor) {
          null => (items: [1, 2], next: 'a'),
          'a' => (items: [3], next: 'b'),
          _ => (items: [4, 5], next: null),
        };
      });
      expect(items, [1, 2, 3, 4, 5]);
      expect(seen, [null, 'a', 'b']);
    });

    test('empty first page gives an empty list', () async {
      final items = await fetchAllPages<int>(
        (cursor) async => (items: <int>[], next: null),
      );
      expect(items, isEmpty);
    });

    test('throws StateError at maxPages', () async {
      var calls = 0;
      await expectLater(
        fetchAllPages<int>((cursor) async {
          calls++;
          return (items: [calls], next: 'more');
        }, maxPages: 3),
        throwsStateError,
      );
      expect(calls, 3);
    });
  });

  test('toPageResult applies cursorFromNext', () {
    final result = toPageResult<int>([1, 2], 'https://h/x?cursor=zz');
    expect(result.items, [1, 2]);
    expect(result.next, 'zz');
    expect(toPageResult<int>([], null).next, isNull);
  });
}
