import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Circular hairline-bordered surface holding one glyph.
class IconBadge extends StatelessWidget {
  final Widget child;
  final double size;

  const IconBadge({super.key, required this.child, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: colors.borderHairline),
      ),
      child: child,
    );
  }
}
