import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/token_store.dart';

/// Test [TokenStore] that records every write in [log].
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({this.refresh, this.user});

  String? refresh;
  SessionUser? user;
  final List<String> log = [];

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> writeRefresh(String token) async {
    log.add('writeRefresh:$token');
    refresh = token;
  }

  @override
  Future<SessionUser?> readUser() async => user;

  @override
  Future<void> writeUser(SessionUser u) async {
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
