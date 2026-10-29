import 'package:api_client/api_client.dart' show Me;

/// Authentication state of the app.
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

  /// Maps the generated `GET /me` model.
  factory SessionUser.fromMe(Me me) => SessionUser(
        id: me.id.toString(),
        email: me.email,
        name: me.name ?? '',
      );

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );

  final String id;
  final String email;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is SessionUser &&
      other.id == id &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);
}
