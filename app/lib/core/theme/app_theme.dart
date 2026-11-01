import 'package:flutter/material.dart';

import 'brand.dart';
import 'tokens.dart';

const _fontFamily = 'Inter';
const _minTarget = Size(48, 48);

/// The app is light-only (ui_deign.md): there is deliberately no dark theme.
ThemeData lightTheme(Brand brand) {
  final accent = _accessible(brand.seedColor);
  final scheme = ColorScheme.fromSeed(seedColor: accent).copyWith(
    brightness: Brightness.light,
    primary: accent,
    onPrimary: Palette.white,
    primaryContainer: Color.alphaBlend(
      accent.withOpacity(0.12),
      Palette.white,
    ),
    onPrimaryContainer: _darken(accent, 0.25),
    secondaryContainer: Palette.bgMuted,
    onSecondaryContainer: Palette.heading,
    surface: Palette.white,
    onSurface: Palette.heading,
    onSurfaceVariant: Palette.body,
    surfaceContainerLowest: Palette.white,
    surfaceContainerLow: Palette.white,
    surfaceContainer: Palette.bg,
    surfaceContainerHigh: Palette.bgMuted,
    surfaceContainerHighest: Palette.bgMuted,
    outline: Palette.borderStrong,
    outlineVariant: Palette.border,
    error: Palette.danger,
    onError: Palette.white,
    errorContainer: Palette.dangerBg,
    onErrorContainer: const Color(0xFF7F1D1D),
    surfaceTint: Colors.transparent,
  );

  OutlinedBorder shape(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(shape(Radii.md));
  const buttonMin = WidgetStatePropertyAll<Size>(_minTarget);
  const buttonPad = WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: Space.lg),
  );
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: color, width: width),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    brightness: Brightness.light,
  );
  final text = _textTheme(base.textTheme, scheme);
  final focusRing = scheme.primary.withOpacity(0.12);

  return base.copyWith(
    scaffoldBackgroundColor: Palette.bg,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    textTheme: text,
    primaryTextTheme: text,
    focusColor: focusRing,
    hoverColor: scheme.primary.withOpacity(0.06),
    splashFactory: InkRipple.splashFactory,
    dividerTheme: const DividerThemeData(
      color: Palette.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonMin,
        shape: buttonShape,
        padding: buttonPad,
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonMin,
        shape: buttonShape,
        padding: buttonPad,
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonMin,
        shape: buttonShape,
        padding: buttonPad,
        foregroundColor: const WidgetStatePropertyAll(Palette.heading),
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.border)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonMin,
        shape: buttonShape,
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(minimumSize: buttonMin),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: Palette.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Palette.body,
      shape: shape(Radii.md),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.white,
      selectedColor: scheme.primaryContainer,
      shape: shape(Radii.sm),
      side: const BorderSide(color: Palette.border),
      labelStyle: text.labelLarge?.copyWith(color: Palette.heading),
      secondaryLabelStyle:
          text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: 14,
      ),
      labelStyle: text.bodyMedium,
      floatingLabelStyle: text.bodyMedium?.copyWith(color: scheme.primary),
      hintStyle: text.bodyLarge?.copyWith(color: Palette.body),
      errorStyle: text.labelSmall?.copyWith(color: Palette.danger),
      border: border(Palette.borderStrong, 1),
      enabledBorder: border(Palette.borderStrong, 1),
      disabledBorder: border(Palette.border, 1),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(Palette.danger, 1),
      focusedErrorBorder: border(Palette.danger, 2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.white,
      foregroundColor: Palette.heading,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: const Border(bottom: BorderSide(color: Palette.border)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: shape(Radii.md),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : Palette.body,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : Palette.body,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.md)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Palette.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: Palette.border),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.heading,
      contentTextStyle: text.bodyMedium?.copyWith(color: Palette.white),
      actionTextColor: Palette.white,
      shape: shape(Radii.sm),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}

TextTheme _textTheme(TextTheme b, ColorScheme s) {
  TextStyle? st(TextStyle? t, double size, FontWeight w, {Color? color}) =>
      t?.copyWith(
        fontSize: size,
        fontWeight: w,
        height: 1.5,
        color: color ?? s.onSurface,
        fontFamily: _fontFamily,
      );
  return b.copyWith(
    // 12 captions/labels, 14 body/UI, 16 input, 20-22 titles, 30-32 page.
    labelSmall:
        st(b.labelSmall, 12, FontWeight.w500, color: s.onSurfaceVariant),
    labelMedium: st(b.labelMedium, 12, FontWeight.w500),
    labelLarge: st(b.labelLarge, 14, FontWeight.w500),
    bodySmall: st(b.bodySmall, 12, FontWeight.w400, color: s.onSurfaceVariant),
    bodyMedium:
        st(b.bodyMedium, 14, FontWeight.w400, color: s.onSurfaceVariant),
    bodyLarge: st(b.bodyLarge, 16, FontWeight.w400),
    titleSmall: st(b.titleSmall, 14, FontWeight.w600),
    titleMedium: st(b.titleMedium, 16, FontWeight.w600),
    titleLarge: st(b.titleLarge, 20, FontWeight.w600),
    headlineSmall: st(b.headlineSmall, 22, FontWeight.w600),
    headlineMedium: st(b.headlineMedium, 24, FontWeight.w700),
    headlineLarge: st(b.headlineLarge, 30, FontWeight.w700),
    displaySmall: st(b.displaySmall, 32, FontWeight.w700),
  );
}

/// Darkens [c] until white text on it reaches WCAG AA (4.5:1).
Color _accessible(Color c) {
  var out = c;
  for (var i = 0; i < 20 && _contrastOnWhite(out) < 4.5; i++) {
    out = _darken(out, 0.05);
  }
  return out;
}

double _contrastOnWhite(Color c) => 1.05 / (c.computeLuminance() + 0.05);

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
