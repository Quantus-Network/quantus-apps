import 'package:flutter/material.dart';

/// The scan window of Figma 05 · Send. Sized to the window itself, it dims
/// everything outside its own bounds and wraps them in four rounded brackets,
/// so it paints past its edges and relies on an ancestor to clip.
class ScanFramePainter extends CustomPainter {
  static const double _bracketGap = 8.25;
  static const double _bracketRadius = 38;
  static const double _bracketArm = 47;
  static const double _reach = 10000;

  final Color accent;
  final Color scrim;
  final double radius;

  const ScanFramePainter({required this.accent, required this.scrim, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final window = Offset.zero & size;
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(window.inflate(_reach))
        ..addRRect(RRect.fromRectAndRadius(window, Radius.circular(radius))),
      Paint()..color = scrim,
    );

    final frame = window.inflate(_bracketGap);
    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final (corner, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * _bracketArm, corner.dy)
          ..lineTo(corner.dx + dx * _bracketRadius, corner.dy)
          ..arcToPoint(
            Offset(corner.dx, corner.dy + dy * _bracketRadius),
            radius: const Radius.circular(_bracketRadius),
            clockwise: dx * dy < 0,
          )
          ..lineTo(corner.dx, corner.dy + dy * _bracketArm),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(ScanFramePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.scrim != scrim || oldDelegate.radius != radius;
}
