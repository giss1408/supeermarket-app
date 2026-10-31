import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/ui/date_format_fr.dart';

void main() {
  group('formatDateRangeFr', () {
    test('same month', () {
      expect(formatDateRangeFr('2026-10-28', '2026-10-31'), 'du 28 au 31 oct.');
    });
    test('different months', () {
      expect(
        formatDateRangeFr('2026-10-28', '2026-11-03'),
        'du 28 oct. au 3 nov.',
      );
    });
    test('first day of a month is 1er', () {
      expect(formatDateRangeFr('2026-11-01', '2026-11-07'), 'du 1er au 7 nov.');
      expect(
        formatDateRangeFr('2026-10-28', '2026-11-01'),
        'du 28 oct. au 1er nov.',
      );
    });
    test('different years include the years', () {
      expect(
        formatDateRangeFr('2026-12-28', '2027-01-03'),
        'du 28 déc. 2026 au 3 janv. 2027',
      );
    });
    test('same day', () {
      expect(formatDateRangeFr('2026-11-03', '2026-11-03'), 'le 3 nov.');
      expect(formatDateRangeFr('2026-11-01', '2026-11-01'), 'le 1er nov.');
    });
    test('all month abbreviations', () {
      const expected = [
        'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
      ];
      for (var m = 1; m <= 12; m++) {
        final mm = m.toString().padLeft(2, '0');
        expect(
          formatDateRangeFr('2026-$mm-05', '2026-$mm-06'),
          'du 5 au 6 ${expected[m - 1]}',
        );
      }
    });
    test('invalid input throws FormatException', () {
      for (final bad in ['', 'abc', '2026-13-01', '2026-02-30', '2026-1-1']) {
        expect(
          () => formatDateRangeFr(bad, '2026-10-31'),
          throwsFormatException,
          reason: bad,
        );
        expect(
          () => formatDateRangeFr('2026-10-31', bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('formatDayFr', () {
    test('formats a single day', () {
      expect(formatDayFr('2026-11-01'), '1er nov.');
      expect(formatDayFr('2026-11-03'), '3 nov.');
      expect(() => formatDayFr('nope'), throwsFormatException);
    });
  });

  group('isPastFr / isFutureFr', () {
    final now = DateTime(2026, 11, 4, 23, 59);
    test('a date is past only when strictly before the device day', () {
      expect(isPastFr('2026-11-03', now), isTrue);
      expect(isPastFr('2026-11-04', now), isFalse);
      expect(isPastFr('2026-11-05', now), isFalse);
    });
    test('future is strictly after the device day', () {
      expect(isFutureFr('2026-11-05', now), isTrue);
      expect(isFutureFr('2026-11-04', now), isFalse);
    });
    test('invalid input is neither past nor future', () {
      expect(isPastFr('garbage', now), isFalse);
      expect(isFutureFr('garbage', now), isFalse);
    });
  });
}
