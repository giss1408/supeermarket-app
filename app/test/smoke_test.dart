import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/app.dart';
import 'package:supermarket_app/core/config/app_config.dart';

void main() {
  testWidgets('shows the French app name with locale fr', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SupermarketApp()));
    await tester.pumpAndSettle();

    expect(find.text('Supermarché'), findsWidgets);
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('fr'));
  });

  test('AppConfig constants', () {
    expect(AppConfig.currencyCode, 'XOF');
    expect(AppConfig.locale, const Locale('fr'));
  });

  testWidgets('has no debug banner', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SupermarketApp()));
    await tester.pumpAndSettle();

    expect(find.byType(Banner), findsNothing);
    expect(find.byType(CheckedModeBanner), findsNothing);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
