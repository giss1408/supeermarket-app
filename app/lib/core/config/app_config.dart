import 'package:flutter/widgets.dart';

/// Build-time configuration. `API_BASE_URL` comes from
/// `--dart-define-from-file=env/<name>.json`.
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the platform auth service. When set, people sign up and sign in THERE (phone + password, WhatsApp activation code), like in the
  /// other apps of the platform; the API only verifies the tokens. Empty = the API's own e-mail sign-in (the original behaviour).
  static const authBaseUrl = String.fromEnvironment('AUTH_BASE_URL');
  static const currencyCode = 'XOF';
  static const locale = Locale('fr');
}
