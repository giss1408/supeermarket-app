import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

sealed class LocationResult {
  const LocationResult();
}

final class Granted extends LocationResult {
  const Granted(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Permission refused; [permanent] when only the system settings can fix it.
final class Denied extends LocationResult {
  const Denied({this.permanent = false});
  final bool permanent;
}

/// The device's location service is switched off.
final class ServiceDisabled extends LocationResult {
  const ServiceDisabled();
}

/// No position could be obtained (timeout or platform error).
final class Unavailable extends LocationResult {
  const Unavailable();
}

abstract class LocationService {
  /// Current approximate position. With `prompt: false` this NEVER shows a
  /// permission dialog; it only uses a permission already granted.
  Future<LocationResult> current({bool prompt = false});

  /// Opens the system settings page that can fix the last failure.
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _timeout = Duration(seconds: 10);

  @override
  Future<LocationResult> current({bool prompt = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ServiceDisabled();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && prompt) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const Denied();
        case LocationPermission.deniedForever:
          return const Denied(permanent: true);
        case LocationPermission.unableToDetermine:
          return const Unavailable();
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      // City-level accuracy is enough for sorting stores and more private.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _timeout,
        ),
      ).timeout(_timeout);
      return Granted(p.latitude, p.longitude);
    } on TimeoutException {
      return const Unavailable();
    } on Object {
      return const Unavailable();
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } on Object {
      // Nothing more to do; the card stays visible.
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
