import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:resonance_network_wallet/v2/components/android_glass.dart';

enum Shape { rounded, circular }

class LiquidGlassBase extends StatelessWidget {
  final double visibility;
  final Color glassColor;
  final Shape shape;
  final double radius;

  final bool centered;
  final Widget child;

  const LiquidGlassBase.rounded({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,
    this.radius = 14.0,
    this.centered = true,
    required this.child,
  }) : shape = Shape.rounded;

  const LiquidGlassBase.circular({
    super.key,
    this.visibility = 1.0,
    this.glassColor = Colors.transparent,
    this.centered = true,
    required this.child,
  }) : shape = Shape.circular,
       radius = 100.0;

  LiquidGlassSettings get _settings => LiquidGlassSettings(
    glassColor: glassColor,
    visibility: visibility,
    thickness: 20,
    blur: 4,
    refractiveIndex: 1.33,
    lightAngle: 45 * (3.1416 / 180),
    lightIntensity: 0.5,
    ambientStrength: -0.2,
    saturation: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (Platform.isAndroid) {
      return AndroidGlass(
        visibility: settings.visibility,
        glassColor: settings.glassColor == Colors.transparent ? const Color(0x1AFFFFFF) : glassColor,
        radius: radius,
        centered: centered,
        child: child,
      );
    } else {
      var liquidGlass = LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        child: child,
      );
      return LiquidGlassLayer(
        settings: settings,
        child: centered ? Center(child: liquidGlass) : liquidGlass,
      );
    }
  }
}
