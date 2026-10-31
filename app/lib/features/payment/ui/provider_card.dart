import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/phone.dart';
import '../../../core/ui/date_format_fr.dart';
import '../../../core/ui/payment_provider.dart';
import '../../../core/util/clock.dart';

/// One mobile-money number: provider (plain text), number in large type,
/// the admin's instructions and a button that copies the number ONLY.
class ProviderCard extends ConsumerWidget {
  const ProviderCard({super.key, required this.method});

  final PaymentMethodRow method;

  String _providerName() {
    try {
      return PaymentProvider.fromApi(method.provider).displayName;
    } on FormatException {
      return method.provider;
    }
  }

  /// `(shown, copied, spoken)`; an invalid number is shown and copied raw.
  ({String shown, String copy, String spoken}) _number() {
    try {
      final shown = formatCiPhone(method.phoneNumber);
      return (
        shown: shown,
        copy: ciPhoneForCopy(method.phoneNumber),
        spoken: shown.replaceAll(' ', ', '),
      );
    } on FormatException {
      final raw = method.phoneNumber;
      return (shown: raw, copy: raw, spoken: raw);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final number = _number();
    final name = _providerName();
    final updated = DateTime.tryParse(method.updatedAt);
    final instructions = method.instructions.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: l.paySemantics(name, number.spoken, instructions),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleLarge),
                  if (method.displayName.isNotEmpty &&
                      method.displayName != name)
                    Text(
                      method.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    number.shown,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(instructions, style: theme.textTheme.bodyMedium),
                  ],
                  if (updated != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formatUpdatedOnFr(updated, now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: number.copy));
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.payCopied)));
              },
              icon: const Icon(Icons.copy),
              label: Text(l.payCopyNumber),
            ),
          ],
        ),
      ),
    );
  }
}
