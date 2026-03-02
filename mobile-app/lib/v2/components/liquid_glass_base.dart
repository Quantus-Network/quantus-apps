import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

enum Shape { rounded, circular }

class LiquidGlassBase extends StatelessWidget {
  final double visibility;
  final Color glassColor;
  final Shape shape;
  final double radius;

  final Widget child;

  const LiquidGlassBase.rounded({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,
    this.radius = 14.0,
    required this.child,
  }) : shape = Shape.rounded;

  const LiquidGlassBase.circular({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,

    required this.child,
  }) : shape = Shape.circular,
       radius = 100.0;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: LiquidGlassSettings(
        glassColor: glassColor,
        visibility: visibility,
        thickness: 20,
        blur: 4,
        refractiveIndex: 1.33,
        lightAngle: 45 * (3.1416 / 180),
        lightIntensity: 0.5,
        ambientStrength: -0.2,
        saturation: 1.5,
      ),
      child: Center(
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: radius),
          child: child,
        ),
      ),
    );
  }
}
