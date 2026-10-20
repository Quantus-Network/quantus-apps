import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One tile per expected frame, lit as the frame arrives, so the missing
/// ones are visible. Above [maxTiles] frames a segmented bar stands in.
class QrFrameMap extends StatelessWidget {
  static const double tile = 10;
  static const double gap = 3;
  static const int maxTiles = 64;

  final int expected;
  final Set<int> seen;
  final int? lastAdded;
  final Animation<double> flash;
  final bool complete;

  const QrFrameMap({
    super.key,
    required this.expected,
    required this.seen,
    required this.flash,
    this.lastAdded,
    this.complete = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double height;
        if (expected > maxTiles) {
          height = 4;
        } else {
          final perRow = ((width + gap) / (tile + gap)).floor().clamp(1, expected);
          final rows = (expected / perRow).ceil();
          height = rows * tile + (rows - 1) * gap;
        }
        return CustomPaint(
          size: Size(width, height),
          painter: _FrameMapPainter(
            expected: expected,
            seen: seen,
            lastAdded: lastAdded,
            flash: flash,
            complete: complete,
            colors: colors,
          ),
        );
      },
    );
  }
}

class _FrameMapPainter extends CustomPainter {
  final int expected;
  final Set<int> seen;
  final int? lastAdded;
  final Animation<double> flash;
  final bool complete;
  final AppColorsV3 colors;

  _FrameMapPainter({
    required this.expected,
    required this.seen,
    required this.lastAdded,
    required this.flash,
    required this.complete,
    required this.colors,
  }) : super(repaint: flash);

  Color _fill(int index) {
    if (complete) return colors.semanticSage;
    if (!seen.contains(index)) return colors.bgSurface2;
    if (index == lastAdded) return Color.lerp(colors.textContent, colors.accentFlare, flash.value)!;
    return colors.accentFlare;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (expected > QrFrameMap.maxTiles) {
      final segment = size.width / expected;
      for (var i = 1; i <= expected; i++) {
        canvas.drawRect(Rect.fromLTWH((i - 1) * segment, 0, segment, size.height), Paint()..color = _fill(i));
      }
      return;
    }
    const tile = QrFrameMap.tile;
    const gap = QrFrameMap.gap;
    final perRow = ((size.width + gap) / (tile + gap)).floor().clamp(1, expected);
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.borderHairline;
    for (var i = 1; i <= expected; i++) {
      final column = (i - 1) % perRow;
      final row = (i - 1) ~/ perRow;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(column * (tile + gap), row * (tile + gap), tile, tile),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = _fill(i));
      if (!seen.contains(i)) canvas.drawRRect(rect, hairline);
    }
  }

  @override
  bool shouldRepaint(_FrameMapPainter old) =>
      old.expected != expected || old.seen != seen || old.lastAdded != lastAdded || old.complete != complete;
}
