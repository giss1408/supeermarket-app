import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network reachability as the sync engine needs it (faked in tests).
abstract class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits `true` when an interface is up, `false` when none is.
  Stream<bool> get changes;
}

class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _up(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _up(await _connectivity.checkConnectivity());
    } on Object {
      return true; // unknown: let the request itself decide
    }
  }

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_up).handleError((_) {});
}

final connectivityMonitorProvider =
    Provider<ConnectivityMonitor>((ref) => ConnectivityPlusMonitor());
