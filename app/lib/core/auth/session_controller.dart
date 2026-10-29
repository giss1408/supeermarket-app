import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../db/daos/sync_meta_keys.dart' as keys;
import '../db/database_provider.dart';
import '../errors/app_error.dart';
import '../errors/error_mapper.dart';
import 'session.dart';
import 'token_store.dart';

/// Outcome of [SessionController.signOut].
sealed class SignOutResult {
  const SignOutResult();
}

final class SignedOut extends SignOutResult {
  const SignedOut();
}

/// Sign-out refused because [count] local changes are not yet synced.
final class BlockedByUnsynced extends SignOutResult {
  const BlockedByUnsynced(this.count);
  final int count;
}

const _logoutTimeout = Duration(seconds: 5);

class SessionController extends Notifier<Session> {
  @override
  Session build() => const Guest();

  TokenStore get _store => ref.read(tokenStoreProvider);
  set _access(String? v) => ref.read(accessTokenProvider).value = v;

  /// Restores the session at app start. Never throws.
  ///
  /// With a stored refresh token AND user the session is restored OFFLINE with
  /// no request (the app must work in a dead zone). No access token is held
  /// then: the auth interceptor refreshes lazily on the first authenticated
  /// request that gets a 401. With a token but no stored user, an online
  /// refresh + `GET /me` is attempted; any failure clears the store.
  Future<void> restore() async {
    try {
      final refresh = await _store.readRefresh();
      if (refresh == null) {
        state = const Guest();
        return;
      }
      final stored = await _store.readUser();
      if (stored != null) {
        state = SignedIn(stored);
        return;
      }
      final pair = await _guard(
        () async => (await ref
                .read(bareApiClientProvider)
                .getAuthApi()
                .authRefreshCreate(
                  tokenRefreshRequest: TokenRefreshRequest(refresh: refresh),
                ))
            .data,
      );
      final user = await _fetchMe(pair.access);
      if (state is SignedIn) return;
      await _establish(refresh: pair.refresh, access: pair.access, user: user);
    } on Object {
      try {
        await _store.clear();
      } on Object {
        // Nothing more to do.
      }
      _access = null;
      state = const Guest();
    }
  }

  Future<void> signIn(String email, String password) async {
    final pair = await _guard(
      () async =>
          (await ref.read(bareApiClientProvider).getAuthApi().authLoginCreate(
                    tokenObtainPairRequest: TokenObtainPairRequest(
                      email: email.trim(),
                      password: password,
                    ),
                  ))
              .data,
    );
    final user = await _fetchMe(pair.access);
    await _establish(refresh: pair.refresh, access: pair.access, user: user);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await ref.read(bareApiClientProvider).getAuthApi().authRegisterCreate(
            registerRequest: RegisterRequest(
              email: email.trim(),
              password: password,
              name: name.trim(),
            ),
          );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // A 2xx whose body could not be parsed still created the account;
      // failing here would make a retry hit "email already used".
      if (status == null || status < 200 || status > 299) {
        throw mapDioException(e);
      }
    } on Object catch (e) {
      throw UnknownError(e);
    }
    await signIn(email, password);
  }

  Future<int> unsyncedCount() =>
      ref.read(appDatabaseProvider).outboxDao.pendingCount();

  Future<SignOutResult> signOut({required bool discardUnsynced}) async {
    if (!discardUnsynced) {
      final count = await unsyncedCount();
      if (count > 0) return BlockedByUnsynced(count);
    }
    try {
      final refresh = await _store.readRefresh();
      if (refresh != null) {
        await ref
            .read(bareApiClientProvider)
            .getAuthApi()
            .authLogoutCreate(logoutRequest: LogoutRequest(refresh: refresh))
            .timeout(_logoutTimeout);
      }
    } on Object {
      // Best effort: offline or server errors never block sign-out.
    }
    await _clearLocal();
    return const SignedOut();
  }

  /// Called when the refresh token is definitively rejected: same local
  /// cleanup as sign-out, no server call, regardless of unsynced operations.
  Future<void> expireSession() => _clearLocal();

  Future<void> _clearLocal() async {
    _access = null;
    try {
      await _store.clear();
      await ref.read(appDatabaseProvider).wipeUserData();
    } finally {
      state = const Guest();
    }
  }

  Future<SessionUser> _fetchMe(String access) async {
    final me = await _guard(
      () async => (await ref.read(bareApiClientProvider).getMeApi().meRetrieve(
        headers: {'Authorization': 'Bearer $access'},
      ))
          .data,
    );
    return SessionUser.fromMe(me);
  }

  /// Persists the credentials, handles account switching, then exposes the
  /// session (last). A storage failure rolls the token store back.
  Future<void> _establish({
    required String refresh,
    required String access,
    required SessionUser user,
  }) async {
    final prevRefresh = await _store.readRefresh();
    final prevUser = await _store.readUser();
    try {
      await _store.writeRefresh(refresh);
      await _store.writeUser(user);
      final db = ref.read(appDatabaseProvider);
      final last = await db.syncMetaDao.get(keys.lastUserId);
      if (last != null && last != user.id) {
        // Previous user's lists, outbox and card must never be visible.
        await db.wipeUserData();
      }
      await db.syncMetaDao.set(keys.lastUserId, user.id);
    } on Object catch (e) {
      try {
        await _store.clear();
        if (prevRefresh != null) await _store.writeRefresh(prevRefresh);
        if (prevUser != null) await _store.writeUser(prevUser);
      } on Object {
        // Best effort rollback.
      }
      throw e is AppError ? e : UnknownError(e);
    }
    _access = access;
    state = SignedIn(user);
  }

  Future<T> _guard<T>(Future<T?> Function() call) async {
    try {
      final value = await call();
      if (value == null) throw const UnknownError('empty response');
      return value;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on AppError {
      rethrow;
    } on Object catch (e) {
      throw UnknownError(e);
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);
