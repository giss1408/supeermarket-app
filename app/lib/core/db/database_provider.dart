import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'daos/card_dao.dart';
import 'daos/lists_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/payment_dao.dart';
import 'daos/public_dao.dart';
import 'daos/stores_dao.dart';
import 'daos/sync_meta_dao.dart';

QueryExecutor openConnection() => LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'supermarket.sqlite'));
      return NativeDatabase.createInBackground(file);
    });

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final publicDaoProvider =
    Provider<PublicDao>((ref) => ref.watch(appDatabaseProvider).publicDao);
final storesDaoProvider =
    Provider<StoresDao>((ref) => ref.watch(appDatabaseProvider).storesDao);
final paymentDaoProvider =
    Provider<PaymentDao>((ref) => ref.watch(appDatabaseProvider).paymentDao);
final listsDaoProvider =
    Provider<ListsDao>((ref) => ref.watch(appDatabaseProvider).listsDao);
final outboxDaoProvider =
    Provider<OutboxDao>((ref) => ref.watch(appDatabaseProvider).outboxDao);
final cardDaoProvider =
    Provider<CardDao>((ref) => ref.watch(appDatabaseProvider).cardDao);
final syncMetaDaoProvider = Provider<SyncMetaDao>(
  (ref) => ref.watch(appDatabaseProvider).syncMetaDao,
);
