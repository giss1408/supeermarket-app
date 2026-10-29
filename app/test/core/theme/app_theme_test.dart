import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket_app/core/theme/app_theme.dart';
import 'package:supermarket_app/core/theme/brand.dart';

double _lum(Color c) => c.computeLuminance();

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final themes = {
    'light': lightTheme(Brand.neutral),
    'dark': darkTheme(Brand.neutral),
  };
  themes.forEach((name, t) {
    group(name, () {
      test('Material 3, Inter, brightness', () {
        expect(t.useMaterial3, isTrue);
        expect(t.textTheme.bodyMedium!.fontFamily, 'Inter');
        expect(t.colorScheme.brightness,
            name == 'light' ? Brightness.light : Brightness.dark);
        expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
      });
      test('contrast >= 4.5', () {
        final s = t.colorScheme;
        expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(
            contrast(s.onSurfaceVariant, s.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(s.error, s.surface), greaterThanOrEqualTo(4.5));
      });
      test('buttons are at least 48 dp high', () {
        for (final style in [
          t.filledButtonTheme.style,
          t.elevatedButtonTheme.style,
          t.outlinedButtonTheme.style,
          t.textButtonTheme.style,
        ]) {
          expect(style!.minimumSize!.resolve({})!.height,
              greaterThanOrEqualTo(48));
        }
      });
      test('rounded cards, chips and inputs', () {
        expect(t.cardTheme.shape, isA<RoundedRectangleBorder>());
        expect(t.chipTheme.shape, isA<RoundedRectangleBorder>());
        final border =
            t.inputDecorationTheme.focusedBorder as OutlineInputBorder;
        expect(border.borderRadius, isNot(BorderRadius.zero));
        expect(border.borderSide.width, greaterThanOrEqualTo(2));
      });
    });
  });

  test('brand seed colour drives the scheme', () {
    const b = Brand(name: 'X', seedColor: Color(0xFFB71C1C));
    expect(lightTheme(b).colorScheme.primary,
        isNot(lightTheme(Brand.neutral).colorScheme.primary));
  });
}
