import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../errors/app_error.dart';
import '../errors/error_mapper.dart';
import 'empty_state.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: error is NetworkError ? Icons.wifi_off : Icons.error_outline,
      title: userMessage(error, l),
      actionLabel: l.actionRetry,
      onAction: onRetry,
    );
  }
}
