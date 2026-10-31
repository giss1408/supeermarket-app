import 'dart:math' as math;

import '../db/app_database.dart';

const _earthRadiusKm = 6371.0088;

/// Great-circle distance in km (haversine, mean Earth radius).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// French distance label: `850 m`, `1,2 km`, `120 km`.
String formatDistanceFr(double km) {
  final metres = (km * 1000 / 10).round() * 10;
  if (metres < 1000) return '$metres m';
  final tenths = (km * 10).round();
  if (tenths >= 1000) return '${(km).round()} km';
  return '${(tenths / 10).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Seconds since midnight of `HH:MM` or `HH:MM:SS`; null when unparsable.
int? _seconds(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final nums = parts.map(int.tryParse).toList();
  if (nums.any((n) => n == null)) return null;
  return nums[0]! * 3600 + nums[1]! * 60 + (nums.length == 3 ? nums[2]! : 0);
}

/// The row for [now]'s weekday (0 = Monday), or null when closed all day.
OpeningHoursRow? todaysHours(List<OpeningHoursRow> week, DateTime now) {
  final weekday = now.weekday - 1;
  for (final r in week) {
    if (r.weekday == weekday) return r;
  }
  return null;
}

/// Whether the store is open at [now] (device local time): `opens` inclusive,
/// `closes` exclusive. No row for the day, or an empty week, means closed.
bool isOpenNow(List<OpeningHoursRow> week, DateTime now) {
  final row = todaysHours(week, now);
  if (row == null) return false;
  final opens = _seconds(row.opens);
  var closes = _seconds(row.closes);
  if (opens == null || closes == null) return false;
  // `00:00` as closing time means midnight at the end of the day.
  if (closes == 0 && opens > 0) closes = 24 * 3600;
  final t = now.hour * 3600 + now.minute * 60 + now.second;
  return t >= opens && t < closes;
}

/// Google Maps search link (dot decimal separator regardless of locale).
Uri mapsUri(double lat, double lng) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

/// `tel:` link: digits and a leading `+` are kept, everything else dropped.
Uri telUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
