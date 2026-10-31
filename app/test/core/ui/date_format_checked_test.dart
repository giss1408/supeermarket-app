import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/ui/date_format_fr.dart';

void main() {
  final now = DateTime(2026, 10, 30, 18);

  test('formatCheckedAtFr', () {
    expect(formatCheckedAtFr(DateTime(2026, 10, 30, 14, 32), now),
        "Vérifié aujourd'hui à 14:32");
    expect(formatCheckedAtFr(DateTime(2026, 10, 28, 9, 5), now),
        'Vérifié le 28 oct. à 09:05');
    expect(formatCheckedAtFr(DateTime(2025, 12, 1, 9, 5), now),
        'Vérifié le 1er déc. 2025 à 09:05');
  });

  test('formatUpdatedOnFr', () {
    expect(
        formatUpdatedOnFr(DateTime(2026, 11, 3), now), 'Mis à jour le 3 nov.');
    expect(formatUpdatedOnFr(DateTime(2026, 11, 1), now),
        'Mis à jour le 1er nov.');
    expect(formatUpdatedOnFr(DateTime(2025, 11, 3), now),
        'Mis à jour le 3 nov. 2025');
  });
}
