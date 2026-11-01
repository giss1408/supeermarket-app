import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/device/screen_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/router/sign_in_gate.dart';
import '../../../core/sync/refresh_outcome.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/error_view.dart';
import '../../../core/ui/skeleton.dart';
import '../data/card_repository.dart';
import '../../../core/theme/tokens.dart';

/// Groups digits four by four for reading at the till: "0419 0957 1937 3".
List<String> groupDigits(String number) {
  final groups = <String>[];
  for (var i = 0; i < number.length; i += 4) {
    groups.add(
        number.substring(i, i + 4 > number.length ? number.length : i + 4));
  }
  return groups;
}

/// Full-screen loyalty card. Works offline from the cached card.
class CardScreen extends ConsumerWidget {
  const CardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    if (ref.watch(sessionProvider) is! SignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.cardTitle)),
        body: EmptyState(
          icon: Icons.card_membership_outlined,
          title: l.cardSignInPrompt,
          actionLabel: l.actionSignIn,
          onAction: () => requireSignIn(context, ref),
        ),
      );
    }
    return const _SignedInCard();
  }
}

class _SignedInCard extends ConsumerStatefulWidget {
  const _SignedInCard();

  @override
  ConsumerState<_SignedInCard> createState() => _SignedInCardState();
}

class _SignedInCardState extends ConsumerState<_SignedInCard>
    with WidgetsBindingObserver {
  late final ScreenController _screen = ref.read(screenControllerProvider);
  bool _qr = false;
  bool _refreshing = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boost();
    unawaited(_refresh());
  }

  void _boost() {
    unawaited(_screen.boostBrightness());
    unawaited(_screen.keepAwake(true));
  }

  void _restore() {
    unawaited(_screen.restoreBrightness());
    unawaited(_screen.keepAwake(false));
  }

  Future<void> _refresh() async {
    final repo = ref.read(cardRepositoryProvider);
    if (!_refreshing) setState(() => _refreshing = true);
    final outcome = await repo.refresh();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _error = outcome is Failed ? outcome.error : null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _boost();
    } else {
      _restore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(cardProvider);
    final row = card.valueOrNull;
    Widget body;
    if (row != null) {
      body = _CardBody(
        number: row.number,
        value: row.barcodeValue,
        qr: _qr,
        onMode: (qr) => setState(() => _qr = qr),
      );
    } else if (card.hasError || (!_refreshing && _error != null)) {
      body = ErrorView(
        error: _error ?? const UnknownError('card'),
        onRetry: _refresh,
      );
    } else {
      body = const _CardSkeleton();
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.cardTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Skeleton(
                height: 200, radius: BorderRadius.all(Radius.circular(20))),
            SizedBox(height: 16),
            Skeleton(width: 220, height: 28),
          ],
        ),
      );
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.number,
    required this.value,
    required this.qr,
    required this.onMode,
  });

  final String number;
  final String value;
  final bool qr;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups = groupDigits(number);
    final spoken = groups.map((g) => g.split('').join(' ')).join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Always black on white, whatever the theme: scanners need it.
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: qr
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: BarcodeWidget(
                              key: const Key('card_qr'),
                              barcode: Barcode.qrCode(),
                              data: value,
                              color: Colors.black,
                              backgroundColor: Colors.white,
                              drawText: false,
                              errorBuilder: _unreadable,
                            ),
                          ),
                        )
                      : BarcodeWidget(
                          key: const Key('card_barcode'),
                          barcode: Barcode.code128(),
                          data: value,
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          height: 120,
                          drawText: false,
                          errorBuilder: _unreadable,
                        ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: l.cardNumberSemantics(spoken),
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      groups.join(' '),
                      key: const Key('card_number'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.cardBarcode)),
                ButtonSegment(value: true, label: Text(l.cardQr)),
              ],
              selected: {qr},
              onSelectionChanged: (s) => onMode(s.first),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.cardHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _unreadable(BuildContext context, String error) =>
      const SizedBox(height: 120);
}
