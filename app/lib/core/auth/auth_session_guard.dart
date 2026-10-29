import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies "which session is this?" for check-then-act sequences that
/// span awaits (token refresh, restore, sign-in, sign-out).
///
/// Every mutator calls [invalidate] synchronously before its first await and
/// performs all its writes inside [exclusive]. Long-running work (a refresh
/// call, a restore) captures [epoch] first and, inside [exclusive], discards
/// its result when the epoch moved on.
class AuthSessionGuard {
  int _epoch = 0;
  Future<void> _tail = Future<void>.value();

  int get epoch => _epoch;

  /// Increments the epoch synchronously and returns the new value.
  int invalidate() => ++_epoch;

  /// Runs [body] after every previously queued section finished. The lock is
  /// released even if [body] throws; the error reaches only this caller.
  /// [body] must not call [exclusive] itself (it would wait on itself).
  Future<T> exclusive<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        return await body();
      } finally {
        done.complete();
      }
    }();
  }
}

/// One guard per container, shared by the session controller and the
/// interceptor.
final authSessionGuardProvider =
    Provider<AuthSessionGuard>((ref) => AuthSessionGuard());
