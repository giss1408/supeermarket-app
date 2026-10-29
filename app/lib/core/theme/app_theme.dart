import 'package:flutter/material.dart';

import 'brand.dart';

const _fontFamily = 'Inter';
const _minTarget = Size(48, 48);
const _radius = 12.0;

ThemeData lightTheme(Brand brand) => _build(brand, Brightness.light);

ThemeData darkTheme(Brand brand) => _build(brand, Brightness.dark);

ThemeData _build(Brand brand, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand.seedColor,
    brightness: brightness,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );
  final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(shape);
  const buttonMin = WidgetStatePropertyAll<Size>(_minTarget);
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: color, width: width),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    brightness: brightness,
  );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    textTheme: base.textTheme.apply(
      fontFamily: _fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin, shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin, shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin, shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin, shape: buttonShape),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outline),
      labelStyle: base.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: border(scheme.outline, 1),
      enabledBorder: border(scheme.outline, 1),
      focusedBorder: border(scheme.primary, 3),
      errorBorder: border(scheme.error, 2),
      focusedErrorBorder: border(scheme.error, 3),
    ),
    focusColor: scheme.primary.withOpacity(0.24),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
  );
}
