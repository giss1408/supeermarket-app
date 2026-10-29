/// Authentication state of the app. Task 9 keeps this public shape.
sealed class Session {
  const Session();
}

final class Guest extends Session {
  const Guest();
}

final class SignedIn extends Session {
  const SignedIn(this.user);

  final SessionUser user;
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.name,
  });

  final String id;
  final String email;
  final String name;
}
