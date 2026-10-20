import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A ring with a check mark, drawn so it scales with any size.
class SuccessMark extends StatelessWidget {
  final double size;

  const SuccessMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SuccessPainter(context.colorsV3.semanticSage));
  }
}

class _SuccessPainter extends CustomPainter {
  final Color color;

  const _SuccessPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - stroke.strokeWidth, stroke);
    final check = Path()
      ..moveTo(size.width * 0.3, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.66)
      ..lineTo(size.width * 0.71, size.height * 0.38);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(_SuccessPainter oldDelegate) => oldDelegate.color != color;
}
