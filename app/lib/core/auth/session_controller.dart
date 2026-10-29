import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// STUB: Task 9 replaces this controller with the real implementation
/// (keeping [Session] and [sessionProvider] as the public shape).
class SessionController extends Notifier<Session> {
  @override
  Session build() => const Guest();

  /// STUB for tests and the provisional sign-in button; removed in Task 9.
  void debugSignIn() => state = const SignedIn(
        SessionUser(id: 'debug', email: 'debug@example.ci', name: 'Debug'),
      );

  /// STUB for tests; removed in Task 9.
  void debugSignOut() => state = const Guest();
}

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);
