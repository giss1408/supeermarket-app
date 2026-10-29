import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';

/// Test-only controller for widget/router tests that do not exercise HTTP:
/// signIn/register just succeed (or throw [failWith]).
class FakeSessionController extends SessionController {
  FakeSessionController({this.failWith});

  final Object? failWith;
  final signInCalls = <(String, String)>[];
  int registerCalls = 0;
  Future<void> Function()? gate;

  static const user =
      SessionUser(id: '7', email: 'u7@example.ci', name: 'Test');

  @override
  Future<void> restore() async {}

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls.add((email, password));
    await gate?.call();
    if (failWith != null) throw failWith!;
    state = const SignedIn(user);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    registerCalls++;
    await gate?.call();
    if (failWith != null) throw failWith!;
    state = const SignedIn(user);
  }

  /// Test helper to force a state.
  void force(Session s) => state = s;
}
