import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'progress_dialog.dart';

enum UnsyncedChoice { syncFirst, discard, cancel }

/// Warns that [count] local changes were not sent yet.
class UnsyncedWarningDialog extends StatelessWidget {
  const UnsyncedWarningDialog({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.unsyncedTitle(count)),
      content: Text(l.unsyncedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, UnsyncedChoice.syncFirst),
          child: Text(l.unsyncedSyncFirst),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, UnsyncedChoice.discard),
          child: Text(l.unsyncedDiscard),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, UnsyncedChoice.cancel),
          child: Text(l.actionCancel),
        ),
      ],
    );
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.unsyncedDiscardConfirmTitle),
      content: Text(l.unsyncedDiscardConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.unsyncedDiscardConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Signs out without ever losing unsynced changes silently.
///
/// Pending operations block the sign-out and the user chooses: sync first
/// (then try again, never signing out while changes remain unless the user
/// explicitly discards), discard after a second confirmation, or cancel.
Future<void> runSignOutFlow(BuildContext context, WidgetRef ref) async {
  final session = ref.read(sessionProvider.notifier);
  final coordinator = ref.read(syncCoordinatorProvider);
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  var result = await session.signOut(discardUnsynced: false);
  while (true) {
    final blocked = result;
    if (blocked is! BlockedByUnsynced) return;
    if (!context.mounted) return;
    final choice = await showDialog<UnsyncedChoice>(
      context: context,
      builder: (_) => UnsyncedWarningDialog(count: blocked.count),
    );
    if (!context.mounted) return;
    switch (choice) {
      case null || UnsyncedChoice.cancel:
        return;
      case UnsyncedChoice.discard:
        if (await _confirmDiscard(context)) {
          await session.signOut(discardUnsynced: true);
          return;
        }
        if (!context.mounted) return;
      case UnsyncedChoice.syncFirst:
        final navigator = showBlockingProgress(context, l.unsyncedSyncing);
        try {
          await coordinator.run(force: true);
          result = await session.signOut(discardUnsynced: false);
        } finally {
          navigator.pop();
        }
        if (result is BlockedByUnsynced && coordinator.status is SyncOffline) {
          messenger
              .showSnackBar(SnackBar(content: Text(l.unsyncedStillOffline)));
        }
    }
  }
}
