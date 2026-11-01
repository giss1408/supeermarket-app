import 'package:flutter/material.dart';

import '../ui/payment_provider.dart';

/// Branding of the app (one build per supermarket chain).
///
/// [seedColor] is the single accent (buttons, links, focus, active states).
/// It must reach 4.5:1 against white; the theme darkens it if it does not.
class Brand {
  const Brand({
    required this.name,
    required this.seedColor,
    this.logoAsset,
    this.providerLogos = const {},
  });

  final String name;
  final Color seedColor;
  final String? logoAsset;
  final Map<PaymentProvider, String?> providerLogos;

  // Green 700: white text on it is 5.0:1.
  static const neutral =
      Brand(name: 'Supermarché', seedColor: Color(0xFF15803D));
}
