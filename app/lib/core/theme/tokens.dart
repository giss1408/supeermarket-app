import 'package:flutter/material.dart';

/// Design tokens (see ui_deign.md). Screens and widgets read these through
/// `Theme.of(context)` where possible; use the constants for spacing and shape.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const pill = 999.0;
}

abstract final class Palette {
  // Backgrounds: white page, light-blue panels (reference: Lidl Plus app).
  static const white = Color(0xFFFFFFFF);
  static const bg = Color(0xFFFFFFFF);
  static const bgMuted = Color(0xFFF0F7FF);
  // Lines and text
  static const border = Color(0xFFC2DFFF);
  static const borderStrong = Color(0xFF8A94A0); // 3:1 on white, input outlines
  static const heading = Color(0xFF1E2124);
  static const title = Color(0xFF002466); // navy card titles
  static const body = Color(0xFF636D79);
  // Semantic
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);
  static const danger = Color(0xFFD0000F); // text-safe red (AA on white)
  static const dangerBg = Color(0xFFFFE8EA);
  static const sale = Color(0xFFE60A14); // badges and price-off marks only
}
