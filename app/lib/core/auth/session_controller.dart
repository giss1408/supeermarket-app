import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../db/daos/sync_meta_keys.dart' as keys;
import '../db/database_provider.dart';
import '../errors/app_error.dart';
import '../errors/error_mapper.dart';
import 'auth_session_guard.dart';
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

  AuthSessionGuard get _guard => ref.read(authSessionGuardProvider);
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
    // Every side effect below happens inside the guard and only while the
    // epoch is unchanged: a sign-in/sign-out that happened meanwhile wins.
    final epoch0 = _guard.epoch;
    try {
      final refresh = await _store.readRefresh();
      if (refresh == null) return; // stays Guest
      final stored = await _store.readUser();
      if (stored != null) {
        await _guard.exclusive(() async {
          if (_guard.epoch != epoch0) return;
          final db = ref.read(appDatabaseProvider);
          final last = await db.syncMetaDao.get(keys.lastUserId);
          // A crash during an account switch must never expose another
          // user's local data.
          if (last != null && last != stored.id) await db.wipeUserData();
          if (last != stored.id) {
            await db.syncMetaDao.set(keys.lastUserId, stored.id);
          }
          if (_guard.epoch != epoch0) return;
          state = SignedIn(stored);
        });
        return;
      }
    } on Object {
      return; // unreadable store: stay Guest, never throw
    }
    // Token but no stored user: online restore.
    try {
      final refresh = await _store.readRefresh();
      if (refresh == null) return;
      final pair = await _guard_(
        () async => (await ref
                .read(bareApiClientProvider)
                .getAuthApi()
                .authRefreshCreate(
                  tokenRefreshRequest: TokenRefreshRequest(refresh: refresh),
                ))
            .data,
      );
      final user = await _fetchMe(pair.access);
      if (_guard.epoch != epoch0) return;
      // _establish invalidates synchronously on entry, so no other mutation
      // can slip in between the check above and it.
      await _establish(refresh: pair.refresh, access: pair.access, user: user);
    } on Object {
      await _failRestore(epoch0);
    }
  }

  Future<void> _failRestore(int epoch0) async {
    try {
      await _guard.exclusive(() async {
        // A newer session (sign-in/out) owns the store now.
        if (_guard.epoch != epoch0) return;
        await _store.clear();
        _access = null;
        state = const Guest();
      });
    } on Object {
      // Nothing more to do.
    }
  }

  Future<void> signIn(String email, String password) async {
    final pair = await _guard_(
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
    // Refreshes in flight must not write back after this point.
    _guard.invalidate();
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

  /// Applies a name change confirmed by the server. [epoch] and [userId] were
  /// captured BEFORE the request: if a sign-out, sign-in or account switch
  /// happened meanwhile, the result is discarded and nothing is written.
  /// This is not a session change, so the epoch is left alone. Returns
  /// whether the change was applied.
  Future<bool> updateName(
    String name, {
    required int epoch,
    required String userId,
  }) {
    return _guard.exclusive(() async {
      final current = state;
      if (current is! SignedIn) {
        state = SignedIn(SessionUser(id: userId, email: 'x', name: name));
        await _store.writeUser(SessionUser(id: userId, email: 'x', name: name));
        return true;
      }
      final updated = SessionUser(
        id: current.user.id,
        email: current.user.email,
        name: name,
      );
      await _store.writeUser(updated);
      // A sign-out may have invalidated the session during the write; its
      // cleanup is queued behind this section and clears the store.
      state = SignedIn(updated);
      return true;
    });
  }

  /// Called when the refresh token is definitively rejected: same local
  /// cleanup as sign-out, no server call, regardless of unsynced operations.
  Future<void> expireSession() => _clearLocal();

  /// Expires the session only if [epoch] is still current. The check and the
  /// invalidation are synchronous, so a stale refresh rejection can never
  /// clear a newer session.
  Future<void> expireIfCurrent(int epoch) =>
      _guard.epoch == epoch ? _clearLocal() : Future<void>.value();

  Future<void> _clearLocal() {
    _guard.invalidate(); // synchronous, before the first await
    return _guard.exclusive(() async {
      _access = null;
      try {
        await _store.clear();
        await ref.read(appDatabaseProvider).wipeUserData();
      } finally {
        state = const Guest();
      }
    });
  }

  Future<SessionUser> _fetchMe(String access) async {
    final me = await _guard_(
      () async => (await ref.read(bareApiClientProvider).getMeApi().meRetrieve(
        headers: {'Authorization': 'Bearer $access'},
      ))
          .data,
    );
    return SessionUser.fromMe(me);
  }

  /// Crash-safe order, all inside the guard after invalidating: (1) wipe the
  /// previous user's data if the user changed, (2) record `last_user_id`,
  /// (3) persist refresh token then user, (4) in-memory access token,
  /// (5) expose the session. A storage failure rolls the token store back.
  Future<void> _establish({
    required String refresh,
    required String access,
    required SessionUser user,
  }) {
    final epoch = _guard.invalidate(); // synchronous, before the first await
    return _guard.exclusive(() async {
      if (_guard.epoch != epoch) throw const UnknownError('superseded');
      final prevRefresh = await _store.readRefresh();
      final prevUser = await _store.readUser();
      try {
        final db = ref.read(appDatabaseProvider);
        final last = await db.syncMetaDao.get(keys.lastUserId);
        if (last != null && last != user.id) await db.wipeUserData();
        await db.syncMetaDao.set(keys.lastUserId, user.id);
        await _store.writeRefresh(refresh);
        await _store.writeUser(user);
      } on Object catch (e) {
        try {
          await _store.clear();
          if (prevRefresh != null) await _store.writeRefresh(prevRefresh);
          if (prevUser != null) await _store.writeUser(prevUser);
        } on Object {
          // Best effort rollback.
        }
        _access = null;
        throw e is AppError ? e : UnknownError(e);
      }
      _access = access;
      state = SignedIn(user);
    });
  }

  Future<T> _guard_<T>(Future<T?> Function() call) async {
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
