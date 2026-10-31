import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/db/app_database.dart';
import 'package:supermarket_app/core/util/store_utils.dart';

OpeningHoursRow row(int weekday, String opens, String closes) =>
    OpeningHoursRow(storeId: 1, weekday: weekday, opens: opens, closes: closes);

void main() {
  group('distanceKm', () {
    // Straight-line (great-circle) distance: 216.08 km, checked independently
    // of the implementation; the "about 200 km" of the task text is loose.
    test('Abidjan to Yamoussoukro is about 216 km', () {
      final d = distanceKm(5.3600, -4.0083, 6.8276, -5.2893);
      expect(d, closeTo(216.08, 0.5));
    });

    test('identical points are 0', () {
      expect(distanceKm(5.36, -4.0083, 5.36, -4.0083), 0);
    });
  });

  test('formatDistanceFr', () {
    expect(formatDistanceFr(0.85), '850 m');
    expect(formatDistanceFr(1.23), '1,2 km');
    expect(formatDistanceFr(120.4), '120 km');
  });

  group('isOpenNow', () {
    // 2026-10-26 is a Monday (weekday 0).
    final week = [row(0, '07:00', '21:00'), row(1, '08:00:00', '18:00:00')];

    test('open inside the window', () {
      expect(isOpenNow(week, DateTime(2026, 10, 26, 12)), isTrue);
      expect(isOpenNow(week, DateTime(2026, 10, 27, 12)), isTrue);
    });
    test('closed before opening', () {
      expect(isOpenNow(week, DateTime(2026, 10, 26, 6, 59)), isFalse);
    });
    test('open exactly at opening', () {
      expect(isOpenNow(week, DateTime(2026, 10, 26, 7)), isTrue);
    });
    test('closed exactly at closing', () {
      expect(isOpenNow(week, DateTime(2026, 10, 26, 21)), isFalse);
    });
    test('closed on a day with no row', () {
      expect(isOpenNow(week, DateTime(2026, 10, 28, 12)), isFalse);
    });
    test('empty week is closed', () {
      expect(isOpenNow(const [], DateTime(2026, 10, 26, 12)), isFalse);
    });
    test('todaysHours picks the row of the current weekday', () {
      expect(todaysHours(week, DateTime(2026, 10, 27, 1))?.weekday, 1);
      expect(todaysHours(week, DateTime(2026, 10, 28, 1)), isNull);
    });
  });

  test('mapsUri and telUri', () {
    expect(
      mapsUri(5.3215, -4.0123).toString(),
      'https://www.google.com/maps/search/?api=1&query=5.3215,-4.0123',
    );
    expect(telUri('+225 27 20 00 01 04').toString(), 'tel:+2252720000104');
  });
}
