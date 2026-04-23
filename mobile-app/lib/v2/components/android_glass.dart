import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AndroidGlass extends StatelessWidget {
  final double visibility;
  final Color glassColor;
  final double radius;
  final double lightIntensity;
  final double lightAngle;
  final double thickness;
  final double ambientStrength;
  final bool centered;
  final Widget child;

  const AndroidGlass({
    super.key,
    required this.child,
    this.visibility = 1.0,
    this.glassColor = const Color(0x1AFFFFFF),
    this.radius = 14.0,
    this.lightIntensity = 0.5,
    this.lightAngle = 45 * (3.1416 / 180),
    this.thickness = 20.0,
    this.ambientStrength = 0.0,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget glass = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        foregroundPainter: _SpecularPainter(
          radius: radius,
          lightIntensity: lightIntensity * visibility,
          lightAngle: lightAngle,
          thickness: thickness * visibility,
          ambientStrength: ambientStrength,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: glassColor),
          child: child,
        ),
      ),
    );

    if (visibility < 1.0) glass = Opacity(opacity: visibility, child: glass);
    return centered ? Center(child: glass) : glass;
  }
}

class _SpecularPainter extends CustomPainter {
  final double radius;
  final double lightIntensity;
  final double lightAngle;
  final double thickness;
  final double ambientStrength;

  const _SpecularPainter({
    required this.radius,
    required this.lightIntensity,
    required this.lightAngle,
    required this.thickness,
    required this.ambientStrength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final bounds = Offset.zero & size;
    final squareBounds = Rect.fromCircle(center: bounds.center, radius: bounds.size.longestSide / 2);

    final intensity = lightIntensity.clamp(0.0, 1.0);
    final thicknessFactor = (thickness / 5).clamp(0.0, 1.0);
    final alpha = Curves.easeOut.transform(intensity);
    final color = Colors.white.withValues(alpha: alpha * thicknessFactor);

    final x = math.cos(lightAngle);
    final y = math.sin(lightAngle);

    final lightCoverage = ui.lerpDouble(.3, .5, intensity)!;
    final alignmentWithShortestSide = (size.aspectRatio < 1 ? y : x).abs();
    final aspectAdjustment = 1 - 1 / size.aspectRatio;
    final gradientScale = aspectAdjustment * (1 - alignmentWithShortestSide);
    final inset = ui.lerpDouble(0, .5, gradientScale.clamp(0, 1))!;
    final secondInset = ui.lerpDouble(lightCoverage, .5, gradientScale.clamp(0, 1))!;

    final shader = LinearGradient(
      colors: [
        color,
        color.withValues(alpha: ambientStrength),
        color.withValues(alpha: ambientStrength),
        color,
      ],
      stops: [inset, secondInset, 1 - secondInset, 1 - inset],
      begin: Alignment(x, y),
      end: Alignment(-x, -y),
    ).createShader(squareBounds);

    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(1, 2, intensity)!
        ..color = color.withValues(alpha: color.a * 0.3)
        ..blendMode = BlendMode.hardLight,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness / 40)
        ..strokeWidth = thickness / 10
        ..color = color.withValues(alpha: color.a * 0.6)
        ..blendMode = BlendMode.overlay,
    );
  }

  @override
  bool shouldRepaint(_SpecularPainter old) =>
      radius != old.radius ||
      lightIntensity != old.lightIntensity ||
      lightAngle != old.lightAngle ||
      thickness != old.thickness ||
      ambientStrength != old.ambientStrength;
}
