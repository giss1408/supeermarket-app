import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/money/xof.dart';

const _n = ' ';
const _s = ' ';

void main() {
  group('formatXof', () {
    final cases = <String, String>{
      '0.00': '0${_s}F CFA',
      '0': '0${_s}F CFA',
      '500.00': '500${_s}F CFA',
      '1500.00': '1${_n}500${_s}F CFA',
      '1500': '1${_n}500${_s}F CFA',
      '1500.5': '1${_n}501${_s}F CFA',
      '1500.50': '1${_n}501${_s}F CFA',
      '1500.49': '1${_n}500${_s}F CFA',
      '-1500.50': '-1${_n}501${_s}F CFA',
      '-1500.49': '-1${_n}500${_s}F CFA',
      '999.99': '1${_n}000${_s}F CFA',
      '1': '1${_s}F CFA',
      '12': '12${_s}F CFA',
      '123': '123${_s}F CFA',
      '1234': '1${_n}234${_s}F CFA',
      '12345': '12${_n}345${_s}F CFA',
      '123456': '123${_n}456${_s}F CFA',
      '1234567.00': '1${_n}234${_n}567${_s}F CFA',
      '123456789012.00': '123${_n}456${_n}789${_n}012${_s}F CFA',
      // beyond double precision (2^53 + 1): proves no double is involved
      '9007199254740993.00':
          '9${_n}007${_n}199${_n}254${_n}740${_n}993${_s}F CFA',
      '0.5': '1${_s}F CFA',
      '0.49': '0${_s}F CFA',
      '-0.49': '0${_s}F CFA',
      '-0': '0${_s}F CFA',
      '0.4999': '0${_s}F CFA',
      '0.5000': '1${_s}F CFA',
    };
    cases.forEach((input, expected) {
      test('"$input"', () => expect(formatXof(input), expected));
    });

    for (final bad in [
      '',
      'abc',
      '1,500.00',
      '1500.00.00',
      '+',
      '.',
      '-',
      ' 1500.00',
      '1500.00 ',
      '1e3',
      '+5',
      '1500.',
      '.5',
    ]) {
      test('throws FormatException for "$bad"', () {
        expect(() => formatXof(bad), throwsFormatException);
      });
    }
  });
}
