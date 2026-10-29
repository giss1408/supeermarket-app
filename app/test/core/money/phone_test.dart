import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/money/phone.dart';

void main() {
  test('formatCiPhone groups by pairs', () {
    expect(formatCiPhone('+2250701020304'), '07 01 02 03 04');
  });
  test('ciPhoneForCopy returns the local digits', () {
    expect(ciPhoneForCopy('+2250701020304'), '0701020304');
  });
  for (final bad in [
    '+33612345678',
    '070102030',
    '0701020304',
    '+22507010203',
    '+22507010203045',
    '+225070102030a',
    '',
    '2250701020304',
  ]) {
    test('throws for "$bad"', () {
      expect(() => formatCiPhone(bad), throwsFormatException);
      expect(() => ciPhoneForCopy(bad), throwsFormatException);
    });
  }
}
