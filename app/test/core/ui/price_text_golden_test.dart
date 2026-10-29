@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/ui/price_text.dart';

/// flutter_test renders with the Ahem font unless fonts are loaded explicitly.
Future<void> _load() async {
  final loader = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await loader.load();
}

Widget _app(ThemeData theme) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: Key('golden'),
            child: Material(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriceText(price: '1500.00'),
                      SizedBox(height: 12),
                      PriceText(price: '1500.00', oldPrice: '2000.00'),
                    ],
                  )),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_load);
  testWidgets('PriceText light', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(lightTheme(Brand.neutral)));
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('../../goldens/price_text_light.png'),
    );
  });
  testWidgets('PriceText dark', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(darkTheme(Brand.neutral)));
    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile('../../goldens/price_text_dark.png'),
    );
  });
}
