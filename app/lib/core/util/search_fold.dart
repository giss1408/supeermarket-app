const _map = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
};

final _combining = RegExp('[̀-ͯ]');

/// Lowercases and strips diacritics of Latin letters, for accent-insensitive
/// search. Mirrored in SQL as `fold_search`. Other characters are unchanged.
String foldSearch(String input) {
  final lower = input.toLowerCase().replaceAll(_combining, '');
  final b = StringBuffer();
  for (final r in lower.runes) {
    final c = String.fromCharCode(r);
    b.write(_map[c] ?? c);
  }
  return b.toString();
}
