import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/router/sign_in_gate.dart';
import 'delete_account_dialog.dart';
import 'edit_name_sheet.dart';
import 'unsynced_warning_dialog.dart';

/// Account tab: sign-in prompt for guests, profile and actions otherwise.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final pay = ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(l.accountPay),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.pay),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.tabAccount)),
      body: ListView(
        children: switch (session) {
          SignedIn(:final user) => [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        user.name.trim().isEmpty
                            ? '?'
                            : user.name.trim().substring(0, 1).toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: theme.textTheme.titleLarge),
                          Text(
                            user.email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.card_membership_outlined),
                title: Text(l.accountCardTile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.card),
              ),
              pay,
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.accountEditName),
                onTap: () => showEditNameSheet(context),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l.accountSignOut),
                onTap: () => runSignOutFlow(context, ref),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l.accountDeleteAccount,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => runDeleteAccountFlow(context, ref),
              ),
            ],
          Guest() => [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.accountGuestPrompt),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => requireSignIn(context, ref),
                          child: Text(l.actionSignIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              pay,
            ],
        },
      ),
    );
  }
}
