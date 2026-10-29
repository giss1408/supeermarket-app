final _ci = RegExp(r'^\+225(\d{10})$');

String _local(String e164) {
  final m = _ci.firstMatch(e164);
  if (m == null) {
    throw FormatException(
        'Not a Côte d\'Ivoire number (+225 + 10 digits)', e164);
  }
  return m.group(1)!;
}

/// `"+2250701020304"` -> `"07 01 02 03 04"`.
String formatCiPhone(String e164) {
  final d = _local(e164);
  return [for (var i = 0; i < 10; i += 2) d.substring(i, i + 2)].join(' ');
}

/// `"+2250701020304"` -> `"0701020304"` (what a user pastes into a dialer).
String ciPhoneForCopy(String e164) => _local(e164);
