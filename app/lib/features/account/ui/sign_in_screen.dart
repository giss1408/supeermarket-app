import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';

/// Placeholder; Task 9 replaces it with the real form. Pops with true on
/// success and false when closed.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key, this.from});

  /// Sanitized location to return to (informational; the dialog pops).
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signInTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.actionClose,
          onPressed: () => context.pop(false),
        ),
      ),
      body: Center(
        // TEST HOOK ONLY: removed when Task 9 adds the real form.
        child: FilledButton(
          onPressed: () {
            ref.read(sessionProvider.notifier).debugSignIn();
            context.pop(true);
          },
          child: Text(l10n.signInProvisional),
        ),
      ),
    );
  }
}
