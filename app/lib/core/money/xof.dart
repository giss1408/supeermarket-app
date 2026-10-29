const _groupSep = ' ';
const _nbsp = ' ';

final _decimal = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$');

/// Formats a decimal string (e.g. `"1500.00"`) as XOF: `"1 500 F CFA"`.
///
/// Groups of three digits are separated by U+202F and a U+00A0 precedes
/// `F CFA`. No decimals: the value is rounded half away from zero on the
/// fractional digits. Works purely on the string (never through `double`).
/// Throws [FormatException] for anything that is not `-?digits(.digits)?`.
String formatXof(String decimal) {
  final m = _decimal.firstMatch(decimal);
  if (m == null) {
    throw FormatException('Not a decimal amount', decimal);
  }
  final negative = m.group(1) == '-';
  var digits = m.group(2)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final fraction = m.group(3) ?? '';
  // Half away from zero: only the first dropped digit matters.
  if (fraction.isNotEmpty && fraction.codeUnitAt(0) >= 0x35) {
    digits = _increment(digits);
  }
  final grouped = _group(digits);
  final sign = negative && digits != '0' ? '-' : '';
  return '$sign$grouped${_nbsp}F CFA';
}

String _increment(String digits) {
  final out = digits.codeUnits.toList();
  var i = out.length - 1;
  while (i >= 0) {
    if (out[i] == 0x39) {
      out[i] = 0x30;
      i--;
    } else {
      out[i]++;
      return String.fromCharCodes(out);
    }
  }
  return '1${String.fromCharCodes(out)}';
}

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_groupSep);
    buf.write(digits[i]);
  }
  return buf.toString();
}
