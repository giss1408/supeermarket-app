import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/errors/app_error.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/ui/empty_state.dart';
import 'package:supermarket_app/core/ui/error_view.dart';
import 'package:supermarket_app/core/ui/offline_banner.dart';
import 'package:supermarket_app/core/ui/price_text.dart';
import 'package:supermarket_app/core/ui/skeleton.dart';

Widget host(
  Widget child, {
  bool disableAnimations = false,
  double textScale = 1.0,
  Size size = const Size(400, 800),
}) {
  return MaterialApp(
    theme: lightTheme(Brand.neutral),
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('PriceText', () {
    testWidgets('shows formatted price, struck old price, one semantics label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const PriceText(price: '1500.00', oldPrice: '2000.00')),
      );
      expect(find.text('1 500 F CFA'), findsOneWidget);
      final old = tester.widget<Text>(find.text('2 000 F CFA'));
      expect(old.style!.decoration, TextDecoration.lineThrough);
      final price = tester.widget<Text>(find.text('1 500 F CFA'));
      expect(price.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()));
      expect(
        find.bySemanticsLabel(
          '1 500 F CFA, ancien prix 2 000 F CFA',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('without old price', (tester) async {
      await tester.pumpWidget(host(const PriceText(price: '500.00')));
      expect(find.text('500 F CFA'), findsOneWidget);
      expect(find.textContaining('ancien'), findsNothing);
    });
  });

  testWidgets('EmptyState renders title, message and action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(EmptyState(
      icon: Icons.search,
      title: 'Aucun résultat',
      message: 'Essayez autre chose',
      actionLabel: 'Réinitialiser',
      onAction: () => taps++,
    )));
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Essayez autre chose'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser'));
    expect(taps, 1);
  });

  testWidgets('ErrorView shows French message and retry fires once',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(ErrorView(
      error: const NetworkError(),
      onRetry: () => retries++,
    )));
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retries, 1);
  });

  testWidgets('OfflineBanner text', (tester) async {
    await tester.pumpWidget(host(const OfflineBanner()));
    expect(find.text('Hors ligne : affichage des dernières données'),
        findsOneWidget);
  });

  group('Skeleton', () {
    testWidgets('does not animate with disableAnimations', (tester) async {
      await tester.pumpWidget(
        host(const Skeleton(width: 100), disableAnimations: true),
      );
      await tester.pumpAndSettle();
      final a = _opacity(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacity(tester), a);
    });

    testWidgets('animates otherwise and disposes cleanly', (tester) async {
      await tester.pumpWidget(host(const Skeleton(width: 100)));
      final a = _opacity(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacity(tester), isNot(a));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('no overflow at a real 320 dp viewport and text scale 2.0', () {
    final widgets = <String, Widget>{
      'PriceText with old price': const PriceText(
        price: '1234567.00',
        oldPrice: '2345678.00',
      ),
      'PriceText without old price': const PriceText(price: '500.00'),
      'PriceText long price': const PriceText(
        price: '123456789012.00',
        oldPrice: '123456789012.00',
      ),
      'EmptyState': EmptyState(
        icon: Icons.shopping_basket,
        title: 'Votre panier est vide pour le moment',
        message: 'Ajoutez des produits depuis les offres de la semaine.',
        actionLabel: 'Voir les offres',
        onAction: () {},
      ),
      'ErrorView network': ErrorView(
        error: const NetworkError(),
        onRetry: () {},
      ),
      'ErrorView timeout': ErrorView(
        error: const AppTimeoutError(),
        onRetry: () {},
      ),
      'ErrorView conflict': ErrorView(
        error: const ApiError(code: 'conflict', status: 409, fields: {}),
        onRetry: () {},
      ),
      'ErrorView csrf': ErrorView(
        error: const ApiError(code: 'csrf_failed', status: 403, fields: {}),
        onRetry: () {},
      ),
      'OfflineBanner': const OfflineBanner(),
      'Skeleton': const Skeleton(width: 200),
    };

    Future<void> pumpAt320(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          w,
          textScale: 2.0,
          size: const Size(320, 640),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
    }

    widgets.forEach((name, w) {
      testWidgets(name, (tester) async {
        await pumpAt320(tester, w);
        expect(tester.getSize(find.byType(Scaffold)).width, 320);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('negative control: the harness detects an overflow', (
      tester,
    ) async {
      await pumpAt320(
        tester,
        const Row(children: [SizedBox(width: 400, height: 20)]),
      );
      final e = tester.takeException();
      expect(e, isA<FlutterError>());
      expect((e! as FlutterError).message, contains('overflowed'));
    });
  });
}

double _opacity(WidgetTester tester) {
  final o = tester.widget<Opacity>(
    find.descendant(
      of: find.byType(Skeleton),
      matching: find.byType(Opacity),
    ),
  );
  return o.opacity;
}
