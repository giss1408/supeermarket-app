import 'package:api_client/api_client.dart' show ApiClient;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_provider.dart';
import '../../../core/auth/auth_session_guard.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/router/routes.dart';
import 'progress_dialog.dart';

Future<bool> _confirm(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.deleteAccountTitle),
      content: Text(l.deleteAccountBody),
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
          child: Text(l.deleteAccountConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Irreversible: asks for confirmation, deletes the account on the server and
/// only when the server confirmed cleans up locally. A failure (offline
/// included) changes nothing.
Future<void> runDeleteAccountFlow(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final session = ref.read(sessionProvider.notifier);
  final ApiClient api = ref.read(apiClientProvider);
  final AuthSessionGuard guard = ref.read(authSessionGuardProvider);

  if (!await _confirm(context)) return;
  if (!context.mounted) return;
  final epoch = guard.epoch;
  final navigator = showBlockingProgress(context, l.deleteAccountProgress);
  AppError? error;
  try {
    await api.getMeApi().meDestroy();
  } on DioException catch (e) {
    error = mapDioException(e);
  } on Object catch (e) {
    error = UnknownError(e);
  }
  navigator.pop();
  if (error != null) {
    // Nothing was changed locally: the session is intact.
    messenger.showSnackBar(SnackBar(content: Text(userMessage(error, l))));
    return;
  }
  // Same cleanup as an expired session (no server logout: the account is
  // gone), skipped if another session took over while the request ran.
  await session.expireIfCurrent(epoch);
  router.go(Routes.offers);
  messenger.showSnackBar(SnackBar(content: Text(l.deleteAccountDone)));
}
