import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_harness.dart';

void main() {
  test('repository_validates_before_writing_and_is_local_first', () async {
    final h = SyncHarness();
    final repo = h.repo;
    expect(() => repo.createList('   '), throwsArgumentError);
    expect(() => repo.createList('x' * 101), throwsArgumentError);
    final list = await repo.createList('  Courses  ');
    expect(() => repo.renameList(list, ''), throwsArgumentError);
    expect(() => repo.addItem(list), throwsArgumentError);
    expect(() => repo.addItem(list, text: '  '), throwsArgumentError);
    expect(
        () => repo.addItem(list, text: 'a', quantity: 0), throwsArgumentError);
    expect(() => repo.addItem(list, text: 'a', quantity: 1000),
        throwsArgumentError);
    final item = await repo.addItem(list, text: 'Pain');
    expect(() => repo.updateItem(item, quantity: 0), throwsArgumentError);
    expect(() => repo.updateItem(item, text: ''), throwsArgumentError);
    await repo.addItem(list, productId: 3, productName: 'Riz');

    // Only the valid writes exist; names are stored trimmed.
    expect((await h.lists()).single.name, 'Courses');
    expect(await h.items(), hasLength(2));
    expect(await repo.pendingCount(), 3);
    expect(h.mutations, 3);

    // Local-first: nothing touched the network.
    expect(h.api.calls, isEmpty);
    final watched = await repo.watchList(list).first;
    expect(watched!.items, hasLength(2));
    expect(await repo.watchLists().first, hasLength(1));
    expect(await repo.watchPendingCount().first, 3);
  });
}
