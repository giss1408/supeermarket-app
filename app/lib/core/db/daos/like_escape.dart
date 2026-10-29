import 'package:drift/drift.dart';

import '../../util/search_fold.dart';

/// Escapes `%`, `_` and the escape character `\` for `LIKE ... ESCAPE '\'`.
String escapeLike(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// `fold_search(column) LIKE %fold(input)% ESCAPE '\'`: accent- and
/// case-insensitive literal contains check. Requires `registerSearchFunctions`
/// on the connection. Returns null when the query folds to nothing (no filter).
Expression<bool>? containsFolded(Expression<String> column, String input) {
  final folded = foldSearch(input).trim();
  if (folded.isEmpty) return null;
  return _LikeEscape(column, '%${escapeLike(folded)}%');
}

class _LikeEscape extends Expression<bool> {
  _LikeEscape(this.column, this.pattern);

  final Expression<String> column;
  final String pattern;

  @override
  Precedence get precedence => Precedence.comparisonEq;

  @override
  void writeInto(GenerationContext context) {
    context.buffer.write('fold_search(');
    column.writeInto(context);
    context.buffer.write(') LIKE ');
    Variable<String>(pattern).writeInto(context);
    context.buffer.write(r" ESCAPE '\'");
  }
}
