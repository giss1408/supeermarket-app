import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../data/lists_repository.dart';

/// All lists of the user, newest first (local data, works offline).
final listsProvider = StreamProvider<List<ShoppingListRow>>(
  (ref) => ref.watch(listsRepositoryProvider).watchLists(),
);

/// One list with its items (unchecked first); null when it does not exist.
final listDetailProvider = StreamProvider.family<ListWithItems?, String>(
  (ref, localId) => ref.watch(listsRepositoryProvider).watchList(localId),
);

/// Number of local changes not yet acknowledged by the server.
final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(listsRepositoryProvider).watchPendingCount(),
);
