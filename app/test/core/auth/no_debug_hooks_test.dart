import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no fake sign-in hook or placeholder wording ships in lib/', () {
    // Built from fragments so this file does not match its own guard.
    final banned = [
      RegExp('debug${'Sign'}', caseSensitive: false),
      RegExp('provi${'sional'}', caseSensitive: false),
      RegExp('provi${'soire'}', caseSensitive: false),
    ];
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File) continue;
      final path = f.path;
      if (!(path.endsWith('.dart') || path.endsWith('.arb'))) continue;
      final text = f.readAsStringSync();
      for (final re in banned) {
        if (re.hasMatch(text)) hits.add('$path: ${re.pattern}');
      }
    }
    expect(hits, isEmpty);
  });
}
