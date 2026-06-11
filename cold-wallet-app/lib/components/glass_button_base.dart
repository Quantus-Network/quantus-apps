import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlassButtonBase extends StatelessWidget {
  final Widget child;
  final double? buttonHeight;
  final double? buttonWidth;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const GlassButtonBase({
    super.key,
    required this.child,
    this.buttonHeight,
    this.buttonWidth,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: buttonHeight,
      width: buttonWidth,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          transform: GradientRotation(30 * math.pi / 180),
          colors: [
            Color(0xFF6F6F6F), // 0%
            Color(0xFF1F1F1F), // 25%
            Color(0xFF0E0E0E), // 50%
            Color(0xFF1F1F1F), // 75%
            Color(0xFF6F6F6F), // 100%
          ],
          stops: [0.0, 0.25, 0.50, 0.75, 1.0],
        ),
      ),
      // The padding acts as the border thickness!
      padding: const EdgeInsets.all(0.5),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            transform: GradientRotation(45 * math.pi / 180),
            colors: [Color(0xFF050505), Color(0xFF171717)],
            stops: [0, 1],
          ),
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(borderRadius: borderRadius, color: const Color.fromRGBO(255, 255, 255, 0.02)),
          child: child,
        ),
      ),
    );
  }
}
