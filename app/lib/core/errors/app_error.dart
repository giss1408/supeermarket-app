/// Typed failures surfaced to the UI.
sealed class AppError implements Exception {
  const AppError();
}

/// No connection / DNS / socket failure.
final class NetworkError extends AppError {
  const NetworkError();
  @override
  String toString() => 'NetworkError';
}

/// Connect, send or receive timeout.
final class AppTimeoutError extends AppError {
  const AppTimeoutError();
  @override
  String toString() => 'AppTimeoutError';
}

/// Error answered by the server.
final class ApiError extends AppError {
  const ApiError({
    required this.code,
    required this.status,
    required this.fields,
    this.detail,
  });

  final String code;
  final int status;

  /// Field errors, already in French from the server; shown by forms.
  final Map<String, List<String>> fields;

  /// Server text for logging/debugging ONLY; never shown to users.
  final String? detail;

  @override
  String toString() => 'ApiError($code, $status)';
}

/// Anything else (cancelled request, bad certificate, programming error...).
final class UnknownError extends AppError {
  const UnknownError(this.cause);
  final Object cause;
  @override
  String toString() => 'UnknownError($cause)';
}
