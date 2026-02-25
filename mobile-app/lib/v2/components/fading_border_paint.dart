import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class FadingEdgePainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final Color borderColor;

  FadingEdgePainter({required this.borderRadius, required this.strokeWidth, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [borderColor.useOpacity(0.5), Colors.transparent, borderColor.useOpacity(0.5), Colors.transparent],
        stops: const [0.2, 0.5, 1, 0.5],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
