import 'package:flutter/material.dart';

import 'auth_form.dart';

/// Register form. Pops with true on success and false when closed.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.from});

  /// Sanitized location to return to; kept when switching between forms.
  final String? from;

  @override
  Widget build(BuildContext context) => AuthForm(register: true, from: from);
}
