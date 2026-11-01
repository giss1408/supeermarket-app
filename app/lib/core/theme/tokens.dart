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
}

abstract final class Palette {
  // Backgrounds
  static const white = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF8FAFC);
  static const bgMuted = Color(0xFFF1F5F9);
  // Lines and text
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFF94A3B8); // 3:1 on white, input outlines
  static const heading = Color(0xFF0F172A);
  static const body = Color(0xFF475569);
  // Semantic
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
}
