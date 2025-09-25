import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef _SphereStyle = ({Gradient gradient, double opacity, double blur});

/// A widget that displays a blurred, colored sphere with various gradient styles.
class Sphere extends StatelessWidget {
  final int variant;
  final double size;

  const Sphere({super.key, required this.variant, required this.size})
    : assert(variant >= 1 && variant <= 16, 'Variant must be between 1 and 16');

  // A map that holds the pre-defined styles for all 16 variants.
  // This approach keeps the build method clean and makes styles easy to manage.
  static final Map<int, _SphereStyle> _sphereStyles = {
    1: (
      gradient: _createGradient(128, [
        (const Color(0xFFED4CCE), 0.2888),
        (const Color(0xFF0000FF), 0.6576),
        (const Color(0xFF1F1FA3), 0.9243),
      ]),
      opacity: 0.3,
      blur: 6.0,
    ),
    2: (
      gradient: _createGradient(230, [
        (const Color(0xFFED4CCE), 0.1505),
        (const Color(0xFF0000FF), 0.5254),
        (const Color(0xFF1F1FA3), 0.8209),
      ]),
      opacity: 0.6,
      blur: 15.5,
    ),
    3: (
      gradient: _createGradient(160, [
        (const Color(0xFFED4CCE), 0.1487),
        (const Color(0xFF0000FF), 0.6367),
        (const Color(0xFF0C1014), 0.9356),
      ]),
      opacity: 0.5,
      blur: 15.0,
    ),
    4: (
      gradient: _createGradient(46, [
        (const Color(0xFFED4CCE), 0.0823),
        (const Color(0xFF0000FF), 0.5637),
        (const Color(0xFF1F1FA3), 0.8585),
      ]),
      opacity: 1.0,
      blur: 16.5,
    ),
    5: (
      gradient: _createGradient(161, [
        (const Color(0xFFED4CCE), 0.1125),
        (const Color(0xFF1F1FA3), 0.3345),
        (const Color(0xFF0C1014), 0.4990),
      ]),
      opacity: 1.0,
      blur: 16.5,
    ),
    6: (
      gradient: _createGradient(3, [
        (const Color(0xFFA74CED), 0.2763),
        (const Color(0xFF0000FF), 0.7319),
        (const Color(0xFF0B0F14), 0.9199),
      ]),
      opacity: 0.4,
      blur: 40.0,
    ),
    7: (
      gradient: _createGradient(200, [
        (const Color(0xFF0000ff), 0.1342),
        (const Color(0xFFED4CCE), 0.4470),
        (const Color(0xFFFFE91F), 0.8108),
      ]),
      opacity: 0.6,
      blur: 15.5,
    ),
     8: (
      gradient: _createGradient(-90, [
        (const Color(0xFF1FFFA7), 0.2976),
        (const Color(0xFF0000FF), 0.7605),
        (const Color(0xFF0C1014), 0.9199),
      ]),
      opacity: 0.4,
      blur: 40.0,
    ),
     9: (
      gradient: _createGradient(-3, [
        (const Color(0xFFFF1F45), 0.2976),
        (const Color(0xFFED4CCE), 0.6423),
        (const Color(0xFF0C1014), 0.8577),
      ]),
      opacity: 0.4,
      blur: 40.0,
    ),
  };

  /// Helper function to create a LinearGradient with rotation.
  static Gradient _createGradient(
    double degrees,
    List<(Color, double)> colorStops,
  ) {
    return LinearGradient(
      colors: colorStops.map((cs) => cs.$1).toList(),
      stops: colorStops.map((cs) => cs.$2).toList(),
      transform: GradientRotation(degrees * (math.pi / 180)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the style for the given variant.
    final style = _sphereStyles[variant]!;

    // The CSS blur in pixels is roughly sigma * 2 in Flutter.
    final double sigma = style.blur;

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Opacity(
        opacity: style.opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: style.gradient,
          ),
        ),
      ),
    );
  }
}
