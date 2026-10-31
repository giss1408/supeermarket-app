/// French date helpers that do not depend on `intl` locale initialisation.
library;

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

final _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

({int year, int month, int day}) _parse(String iso) {
  final m = _iso.firstMatch(iso);
  if (m == null) throw FormatException('Expected YYYY-MM-DD', iso);
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final check = DateTime.utc(y, mo, d);
  if (check.year != y || check.month != mo || check.day != d) {
    throw FormatException('Not a calendar date', iso);
  }
  return (year: y, month: mo, day: d);
}

String _day(int d) => d == 1 ? '1er' : '$d';

/// `1er nov.` / `3 nov.` for an ISO `YYYY-MM-DD` date.
String formatDayFr(String iso) {
  final d = _parse(iso);
  return '${_day(d.day)} ${_months[d.month - 1]}';
}

/// `du 28 au 31 oct.`, `du 28 oct. au 3 nov.`, `le 3 nov.`, or with years
/// when they differ. Throws [FormatException] on invalid input.
String formatDateRangeFr(String isoFrom, String isoTo) {
  final a = _parse(isoFrom);
  final b = _parse(isoTo);
  final ma = _months[a.month - 1];
  final mb = _months[b.month - 1];
  if (a.year != b.year) {
    return 'du ${_day(a.day)} $ma ${a.year} au ${_day(b.day)} $mb ${b.year}';
  }
  if (a.month != b.month) {
    return 'du ${_day(a.day)} $ma au ${_day(b.day)} $mb';
  }
  if (a.day == b.day) return 'le ${_day(a.day)} $ma';
  return 'du ${_day(a.day)} au ${_day(b.day)} $ma';
}

int _cmp(String iso, DateTime now) {
  final d = _parse(iso);
  final a = DateTime.utc(d.year, d.month, d.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  return a.compareTo(b);
}

/// True when the ISO date is strictly before the day of [now]. Display hint
/// only. Invalid input yields false.
bool isPastFr(String isoDate, DateTime now) {
  try {
    return _cmp(isoDate, now) < 0;
  } on FormatException {
    return false;
  }
}

/// True when the ISO date is strictly after the day of [now]. Invalid input
/// yields false.
bool isFutureFr(String isoDate, DateTime now) {
  try {
    return _cmp(isoDate, now) > 0;
  } on FormatException {
    return false;
  }
}
