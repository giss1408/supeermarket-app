/// Parses a SERVER timestamp as a UTC instant (a string without zone is
/// taken as UTC, never as device-local time).
DateTime parseServerInstant(String raw) {
  final d = DateTime.parse(raw);
  if (d.isUtc) return d;
  return DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second,
      d.millisecond, d.microsecond);
}

/// ISO-8601 UTC string with `Z`.
String formatServerInstant(DateTime d) => d.toUtc().toIso8601String();

/// Returns the later of two server timestamp strings (raw text kept).
String laterServerStamp(String? a, String b) {
  if (a == null) return b;
  return parseServerInstant(b).isAfter(parseServerInstant(a)) ? b : a;
}
