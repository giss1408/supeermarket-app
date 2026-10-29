import 'package:flutter/widgets.dart';

/// Build-time configuration. `API_BASE_URL` comes from
/// `--dart-define-from-file=env/<name>.json`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const currencyCode = 'XOF';
  static const locale = Locale('fr');
}
