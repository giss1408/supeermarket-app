// Written, not yet run on a device (ruling R29). Needs a running backend:
//   flutter test integration_test/offline_list_sync_test.dart \
//     --dart-define-from-file=env/dev.json
// (use env/dev_ios.json on an iOS simulator).
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supermarket_app/core/api/api_provider.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/db/database_provider.dart';
import 'package:supermarket_app/core/sync/lists_api.dart';
import 'package:supermarket_app/core/sync/sync_coordinator.dart';
import 'package:supermarket_app/features/lists/data/lists_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a list created offline reaches the server once back online',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    addTearDown(container.dispose);

    final gate = container.read(networkGateProvider);
    final session = container.read(sessionProvider.notifier);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'e2e$stamp@example.ci';

    // Online: create the account and sign in.
    await session.register(
        email: email, password: 'Sup3r-secret-pw', name: 'E2E');
    await session.signIn(email, 'Sup3r-secret-pw');
    expect(container.read(sessionProvider), isA<SignedIn>());

    // Offline: the list is written locally and queued, never awaiting the net.
    gate.online = false;
    final lists = container.read(listsRepositoryProvider);
    final name = 'Courses $stamp';
    final localId = await lists.createList(name);
    await lists.addItem(localId, text: 'Riz 5 kg', quantity: 2);
    expect(await lists.pendingCount(), greaterThan(0));

    final coordinator = container.read(syncCoordinatorProvider);
    await coordinator.run(force: true);
    expect(await lists.pendingCount(), greaterThan(0),
        reason: 'nothing can be pushed while offline');

    // Back online: the queue drains and the server has the list and its item.
    gate.online = true;
    await coordinator.run(force: true);
    expect(await lists.pendingCount(), 0);

    final api = container.read(listsApiProvider);
    final page = await api.listLists();
    final remote = page.items.where((l) => l.name == name).toList();
    expect(remote, hasLength(1), reason: 'exactly one list, no duplicate');
    final detail = await api.getList(remote.single.id);
    expect(detail.items.map((i) => i.text), ['Riz 5 kg']);
    expect(detail.items.single.quantity, 2);
  });
}
