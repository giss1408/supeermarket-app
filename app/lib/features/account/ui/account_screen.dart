import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/router/sign_in_gate.dart';

/// Placeholder replaced by a later task; offers sign-in to guests.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guest = ref.watch(sessionProvider) is Guest;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabAccount)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.placeholderAccount),
            if (guest) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => requireSignIn(context, ref),
                child: Text(l10n.actionSignIn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
