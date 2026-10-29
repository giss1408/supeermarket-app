import 'package:sqlite3/sqlite3.dart';

import '../util/search_fold.dart';

/// Registers the SQL helpers used by search. Pass as `setup:` to every
/// `NativeDatabase`. Top-level on purpose: it runs in the background isolate.
void registerSearchFunctions(Database db) {
  db.createFunction(
    functionName: 'fold_search',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: _foldSearchSql,
  );
}

Object? _foldSearchSql(List<Object?> args) {
  final v = args.first;
  if (v == null) return null;
  return foldSearch(v is String ? v : v.toString());
}
