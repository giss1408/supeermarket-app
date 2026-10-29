import 'package:flutter/material.dart';

import '../ui/payment_provider.dart';

/// Branding of the app (one build per supermarket chain).
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

  static const neutral =
      Brand(name: 'Supermarché', seedColor: Color(0xFF2E9E5B));
}
