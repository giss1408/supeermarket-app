import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/tokens.dart';

/// The brand mark, or nothing when the brand has no logo asset.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.brand = Brand.neutral, this.size = 64});

  final Brand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = brand.logoAsset;
    if (asset == null) return const SizedBox.shrink();
    return Semantics(
      label: brand.name,
      image: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: Image.asset(asset, width: size, height: size),
        ),
      ),
    );
  }
}
