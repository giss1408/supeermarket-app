import 'package:supermarket_app/core/auth/session.dart';
import 'package:supermarket_app/core/auth/session_controller.dart';

/// Test-only controller for widget/router tests that do not exercise HTTP:
/// signIn/register just succeed (or throw [failWith]).
class FakeSessionController extends SessionController {
  FakeSessionController({this.failWith, this.startIn});

  final Object? failWith;

  /// The session the controller starts in (Guest by default).
  final Session? startIn;

  @override
  Session build() => startIn ?? const Guest();
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
    _maybeFail('signIn');
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

  // --- the platform auth service flow (phone + password, WhatsApp code) ---
  final registerPhoneCalls = <({String phone, String password, String name})>[];
  final activateCalls = <({String phone, String code, String password})>[];
  final resetCalls = <String>[];
  final passwordChanges = <String>[];

  /// Failure to throw per step, by name: signIn, registerPhone, activate, reset, completePasswordChange (cleared after being thrown once).
  final failures = <String, Object>{};

  void _maybeFail(String step) {
    final f = failures.remove(step);
    if (f != null) throw f;
  }

  @override
  Future<void> registerPhone(
      {required String phone,
      required String password,
      required String name}) async {
    registerPhoneCalls.add((phone: phone, password: password, name: name));
    _maybeFail('registerPhone');
  }

  @override
  Future<void> activate(
      {required String phone,
      required String code,
      required String password}) async {
    activateCalls.add((phone: phone, code: code, password: password));
    _maybeFail('activate');
    state = const SignedIn(user);
  }

  @override
  Future<void> requestPasswordReset(String phone) async {
    resetCalls.add(phone);
    _maybeFail('reset');
  }

  @override
  Future<void> completePasswordChange(String newPassword) async {
    passwordChanges.add(newPassword);
    _maybeFail('completePasswordChange');
    state = const SignedIn(user);
  }

  /// Test helper to force a state.
  void force(Session s) => state = s;
}
