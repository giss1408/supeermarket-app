import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session.dart';

/// Persistent auth data. Only the refresh token and the signed-in user are
/// ever persisted; the access token lives in memory only.
abstract class TokenStore {
  Future<String?> readRefresh();
  Future<void> writeRefresh(String token);
  Future<SessionUser?> readUser();
  Future<void> writeUser(SessionUser user);

  /// Removes both the refresh token and the user.
  Future<void> clear();
}

/// [TokenStore] backed by the platform keystore (Keychain / encrypted
/// shared preferences).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const refreshKey = 'auth.refresh_token';
  static const userKey = 'auth.user';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefresh() => _storage.read(key: refreshKey);

  @override
  Future<void> writeRefresh(String token) =>
      _storage.write(key: refreshKey, value: token);

  @override
  Future<SessionUser?> readUser() async {
    final raw = await _storage.read(key: userKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SessionUser.fromJson(decoded);
    } on Object {
      // Corrupt entry: treated as absent.
    }
    return null;
  }

  @override
  Future<void> writeUser(SessionUser user) =>
      _storage.write(key: userKey, value: jsonEncode(user.toJson()));

  @override
  Future<void> clear() async {
    await _storage.delete(key: refreshKey);
    await _storage.delete(key: userKey);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
