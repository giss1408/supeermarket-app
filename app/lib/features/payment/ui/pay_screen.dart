import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/ui/date_format_fr.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/util/clock.dart';
import '../state/payment_controller.dart';
import 'provider_card.dart';
import '../../../core/theme/tokens.dart';

/// Mobile-money numbers. Refreshes from the server EVERY time it opens and
/// warns loudly whenever the numbers could not be confirmed.
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key});

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  @override
  void initState() {
    super.initState();
    // Once per screen instance, after the first frame (providers cannot be
    // modified while building).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() =>
      ref.read(paymentRefreshProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final refresh = ref.watch(paymentRefreshProvider);
    final methods = ref.watch(paymentMethodsProvider);
    final checked = ref.watch(paymentLastCheckedProvider).valueOrNull;
    final now = ref.watch(clockProvider)();

    final loading = refresh is Idle || refresh is Loading;
    final failed = refresh is FailedState;
    final warn = failed || (checked == null && !loading);
    final list = methods.valueOrNull;

    final header = <Widget>[
      if (warn) ...[
        _StaleWarning(text: l.payStaleWarning),
        const SizedBox(height: 12),
      ],
      _ExplanationCard(text: l.payExplanation),
      const SizedBox(height: 12),
      if (loading)
        _Checking(text: l.payChecking)
      else if (!failed && checked != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            formatCheckedAtFr(checked, now),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
    ];

    final Widget content;
    if (list != null && list.isNotEmpty) {
      content = _cards(list);
    } else if (list == null || loading) {
      content = _skeleton();
    } else if (refresh is FailedState) {
      content = SizedBox(
        height: 320,
        child: ErrorView(error: refresh.error, onRetry: _refresh),
      );
    } else {
      content = SizedBox(
        height: 320,
        child: EmptyState(icon: Icons.payments_outlined, title: l.payEmpty),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.payTitle)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [...header, content],
        ),
      ),
    );
  }

  Widget _cards(List<PaymentMethodRow> list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final m in list) ProviderCard(method: m)],
      );

  Widget _skeleton() => const Column(
        children: [
          Skeleton(height: 160),
          SizedBox(height: 12),
          Skeleton(height: 160),
        ],
      );
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}

class _Checking extends StatelessWidget {
  const _Checking({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _StaleWarning extends StatelessWidget {
  const _StaleWarning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
