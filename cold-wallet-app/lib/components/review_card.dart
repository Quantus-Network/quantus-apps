import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The surface card a signer checks against the phone (Figma Cold Wallet /
/// Approve).
class ReviewCard extends StatelessWidget {
  final Widget child;

  const ReviewCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.lgBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: child,
    );
  }
}
