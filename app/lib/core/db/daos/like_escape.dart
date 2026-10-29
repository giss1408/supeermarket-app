import 'package:drift/drift.dart';

/// Escapes `%`, `_` and the escape character `\` for `LIKE ... ESCAPE '\'`.
String escapeLike(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// `column LIKE %input% ESCAPE '\'`: a literal, case-insensitive (ASCII)
/// contains check. Drift 2.23's `like` has no ESCAPE support.
Expression<bool> containsLiteral(Expression<String> column, String input) =>
    _LikeEscape(column, '%${escapeLike(input)}%');

class _LikeEscape extends Expression<bool> {
  _LikeEscape(this.column, this.pattern);

  final Expression<String> column;
  final String pattern;

  @override
  Precedence get precedence => Precedence.comparisonEq;

  @override
  void writeInto(GenerationContext context) {
    column.writeInto(context);
    context.buffer.write(' LIKE ');
    Variable<String>(pattern).writeInto(context);
    context.buffer.write(r" ESCAPE '\'");
  }
}
