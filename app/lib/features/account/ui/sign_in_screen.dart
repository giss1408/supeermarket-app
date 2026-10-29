import 'package:flutter/material.dart';

import 'auth_form.dart';

/// SignIn form. Pops with true on success and false when closed.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, this.from});

  /// Sanitized location to return to; kept when switching between forms.
  final String? from;

  @override
  Widget build(BuildContext context) => AuthForm(register: false, from: from);
}
