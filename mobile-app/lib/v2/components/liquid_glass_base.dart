import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

enum Shape { rounded, circular }

class LiquidGlassBase extends StatelessWidget {
  final double visibility;
  final Color glassColor;
  final Shape shape;

  final Widget child;

  const LiquidGlassBase.rounded({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,
    this.shape = Shape.rounded,
    required this.child,
  });

  const LiquidGlassBase.circular({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,
    this.shape = Shape.circular,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = shape == Shape.rounded ? 14.0 : 100.0;

    return LiquidGlassLayer(
      settings: LiquidGlassSettings(
        glassColor: glassColor,
        visibility: visibility,
        thickness: 20,
        blur: 4,
        refractiveIndex: 1.33,
        lightAngle: 45 * (3.1416 / 180),
        lightIntensity: 0.8,
        ambientStrength: 0.5,
        saturation: 1.5,
      ),
      child: Center(
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: effectiveRadius),
          child: child,
        ),
      ),
    );
  }
}
