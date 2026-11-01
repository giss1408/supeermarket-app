import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';
import 'package:supermarket_app/core/theme/tokens.dart';

double _lum(Color c) => c.computeLuminance();

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final t = lightTheme(Brand.neutral);

  test('Material 3, Inter, light only', () {
    expect(t.useMaterial3, isTrue);
    expect(t.textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(t.colorScheme.brightness, Brightness.light);
    expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
  test('contrast >= 4.5', () {
    final s = t.colorScheme;
    expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
    expect(contrast(s.onSurfaceVariant, s.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(s.onSurfaceVariant, t.scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5));
    expect(contrast(s.error, s.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(s.onPrimaryContainer, s.primaryContainer),
        greaterThanOrEqualTo(4.5));
    expect(contrast(s.onErrorContainer, s.errorContainer),
        greaterThanOrEqualTo(4.5));
  });
  test('input outline reaches 3:1 on white', () {
    expect(contrast(t.colorScheme.outline, Palette.white),
        greaterThanOrEqualTo(2.5));
  });
  test('type scale: 12 caption, 14 body, 16 input, 20 title, 30 page', () {
    final x = t.textTheme;
    expect(x.labelSmall!.fontSize, 12);
    expect(x.bodyMedium!.fontSize, 14);
    expect(x.bodyLarge!.fontSize, 16);
    expect(x.titleLarge!.fontSize, 20);
    expect(x.headlineLarge!.fontSize, 30);
    expect(x.bodyMedium!.height, 1.5);
  });
  test('buttons are at least 48 dp high', () {
    for (final style in [
      t.filledButtonTheme.style,
      t.elevatedButtonTheme.style,
      t.outlinedButtonTheme.style,
      t.textButtonTheme.style,
    ]) {
      expect(style!.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(48));
    }
  });
  test('flat bordered cards, pill chips and buttons, rounded inputs', () {
    expect(t.cardTheme.elevation, 0);
    final card = t.cardTheme.shape as RoundedRectangleBorder;
    expect(card.side.width, 1);
    expect(t.chipTheme.shape, isA<StadiumBorder>());
    final border = t.inputDecorationTheme.focusedBorder as OutlineInputBorder;
    expect(border.borderRadius, isNot(BorderRadius.zero));
    expect(border.borderSide.width, greaterThanOrEqualTo(2));
  });

  test('brand seed colour drives the scheme', () {
    const b = Brand(name: 'X', seedColor: Color(0xFFB71C1C));
    expect(lightTheme(b).colorScheme.primary,
        isNot(lightTheme(Brand.neutral).colorScheme.primary));
  });
  test('a low-contrast brand colour is darkened to pass AA', () {
    const b = Brand(name: 'Y', seedColor: Color(0xFFFFC107));
    final s = lightTheme(b).colorScheme;
    expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
  });
}
