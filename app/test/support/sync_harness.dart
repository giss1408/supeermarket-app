import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/sync/connectivity_monitor.dart';
import 'package:supermarket_app/core/sync/outbox_pusher.dart';
import 'package:supermarket_app/core/sync/sync_coordinator.dart';
import 'package:supermarket_app/features/lists/data/lists_repository.dart';

import '../core/db/test_db.dart';
import 'fake_lists_api.dart';

class FakeConnectivity implements ConnectivityMonitor {
  bool online = true;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => controller.stream;
}

const userA = SessionUser(id: '7', email: 'a@example.ci', name: 'A');
const userB = SessionUser(id: '8', email: 'b@example.ci', name: 'B');

/// Real repository + coordinator on an in-memory DB and a [FakeListsApi].
class SyncHarness {
  SyncHarness({
    DateTime? now,
    FakeListsApi? api,
    AppDatabase? db,
    Session? session,
  })  : now = now ?? DateTime.utc(2026, 10, 29, 8),
        api = api ?? FakeListsApi(),
        db = db ?? createTestDb(),
        session = session ?? const SignedIn(userA) {
    // Several isolated in-memory databases per test (other users, restarts).
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    repo = ListsRepository(
      db: this.db,
      clock: () => this.now,
      onMutated: () => mutations++,
    );
    coordinator = SyncCoordinator(
      db: this.db,
      api: () => this.api,
      clock: () => this.now,
      connectivity: connectivity,
      readSession: () => this.session,
      onRejection: rejections.add,
      observeLifecycle: false,
    );
    addTearDown(coordinator.dispose);
  }

  final AppDatabase db;
  final FakeListsApi api;
  final connectivity = FakeConnectivity();
  final rejections = <SyncRejection>[];
  DateTime now;
  Session session;
  int mutations = 0;
  late final ListsRepository repo;
  late final SyncCoordinator coordinator;

  /// A new process on the same database and server (app restart).
  SyncHarness restart({DateTime? now}) => SyncHarness(
        now: now ?? this.now,
        api: api,
        db: db,
        session: session,
      );

  Future<void> sync() => coordinator.run(force: true);

  Future<List<ShoppingListRow>> lists() => db.listsDao.allLists();
  Future<List<ListItemRow>> items() => db.select(db.listItems).get();
  Future<List<OutboxOpRow>> ops() => db.outboxDao.pendingInOrder();
  Future<String?> lastPull() => db.syncMetaDao.get('lists_last_pull');
}
