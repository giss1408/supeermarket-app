import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/token_store.dart';

/// Test [TokenStore] that records every write in [log].
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({this.refresh, this.user});

  String? refresh;
  SessionUser? user;
  final List<String> log = [];

  /// Test hooks to pause a call at an exact await.
  Future<void> Function(String token)? beforeWriteRefresh;
  Future<void> Function(SessionUser user)? beforeWriteUser;
  Future<void> Function()? beforeReadUser;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> writeRefresh(String token) async {
    await beforeWriteRefresh?.call(token);
    log.add('writeRefresh:$token');
    refresh = token;
  }

  @override
  Future<SessionUser?> readUser() async {
    final read = user; // value as of the read, before any pause
    await beforeReadUser?.call();
    return read;
  }

  @override
  Future<void> writeUser(SessionUser u) async {
    await beforeWriteUser?.call(u);
    log.add('writeUser:${u.id}');
    user = u;
  }

  @override
  Future<void> clear() async {
    log.add('clear');
    refresh = null;
    user = null;
  }
}
