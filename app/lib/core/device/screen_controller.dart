import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Screen settings the loyalty card needs while it is shown at the till.
abstract class ScreenController {
  /// Sets this app's brightness to maximum.
  Future<void> boostBrightness();

  /// Gives brightness back to the system setting.
  Future<void> restoreBrightness();

  /// Keeps the screen from sleeping while [on].
  Future<void> keepAwake(bool on);
}

/// Plugin-backed implementation. A plugin failure (unsupported platform,
/// missing permission) must never crash the screen, so every call is guarded.
class PluginScreenController implements ScreenController {
  @override
  Future<void> boostBrightness() => _guard(
        () => ScreenBrightness().setApplicationScreenBrightness(1.0),
      );

  @override
  Future<void> restoreBrightness() => _guard(
        () => ScreenBrightness().resetApplicationScreenBrightness(),
      );

  @override
  Future<void> keepAwake(bool on) =>
      _guard(() => on ? WakelockPlus.enable() : WakelockPlus.disable());

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Best effort only.
    }
  }
}

final screenControllerProvider =
    Provider<ScreenController>((ref) => PluginScreenController());
