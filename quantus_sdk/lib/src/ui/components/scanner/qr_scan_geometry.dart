import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Maps capture-image points onto a preview that shows the image with
/// `BoxFit.cover`. [mirrored] flips x for previews shown mirrored while the
/// frames are not.
List<Offset> mapCornersToPreview(List<Offset> corners, Size captureSize, Size previewSize, {bool mirrored = false}) {
  if (corners.length != 4 || captureSize.isEmpty || previewSize.isEmpty) return const [];
  final scale = math.max(previewSize.width / captureSize.width, previewSize.height / captureSize.height);
  final dx = (previewSize.width - captureSize.width * scale) / 2;
  final dy = (previewSize.height - captureSize.height * scale) / 2;
  return [
    for (final c in corners)
      Offset(mirrored ? previewSize.width - (c.dx * scale + dx) : c.dx * scale + dx, c.dy * scale + dy),
  ];
}

Offset quadCenter(List<Offset> quad) => quad.fold(Offset.zero, (sum, p) => sum + p) / quad.length.toDouble();

/// The same four points in a fixed order: around the centroid, starting at
/// the point nearest the top-left, so painters never depend on the source's
/// corner order.
List<Offset> normalizeQuad(List<Offset> quad) {
  if (quad.length != 4) return const [];
  final center = quadCenter(quad);
  final sorted = [...quad]
    ..sort(
      (a, b) =>
          math.atan2(a.dy - center.dy, a.dx - center.dx).compareTo(math.atan2(b.dy - center.dy, b.dx - center.dx)),
    );
  var start = 0;
  for (var i = 1; i < 4; i++) {
    if (sorted[i].dx + sorted[i].dy < sorted[start].dx + sorted[start].dy) start = i;
  }
  return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
}

/// Rotation of a normalized quad's top edge.
double quadAngle(List<Offset> quad) => math.atan2(quad[1].dy - quad[0].dy, quad[1].dx - quad[0].dx);

/// A rounded rectangle, rotated by [angle] around [center].
class RotatedRRect {
  final Offset center;
  final Size size;
  final double angle;
  final double radius;

  const RotatedRRect({required this.center, required this.size, required this.angle, required this.radius});

  Path toPath() =>
      (Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height),
              Radius.circular(radius),
            ),
          ))
          .transform(_transform);

  Float64List get _transform {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, center.dx, center.dy, 0, 1]);
  }
}

/// A soft hint at the phone holding the QR: the code's box widened and
/// stretched to a phone's proportions, rotated with it, kept inside the preview.
RotatedRRect deviceHighlightRect(List<Offset> quad, Size previewSize) {
  final q = normalizeQuad(quad);
  final width = ((q[1] - q[0]).distance + (q[2] - q[3]).distance) / 2;
  final height = ((q[3] - q[0]).distance + (q[2] - q[1]).distance) / 2;
  final side = math.max(width, height);
  final deviceWidth = math.min(side * 1.3, previewSize.width - 16);
  final deviceHeight = math.min(side * 2.4, previewSize.height - 16);
  final center = quadCenter(q);
  final clamped = Offset(
    center.dx.clamp(8 + deviceWidth / 2, previewSize.width - 8 - deviceWidth / 2),
    center.dy.clamp(8 + deviceHeight / 2, previewSize.height - 8 - deviceHeight / 2),
  );
  return RotatedRRect(
    center: clamped,
    size: Size(deviceWidth, deviceHeight),
    angle: quadAngle(q),
    radius: (deviceWidth * 0.1).clamp(12.0, 40.0),
  );
}

/// [quad] scaled around its centre by [factor].
List<Offset> scaleQuad(List<Offset> quad, double factor) {
  final center = quadCenter(quad);
  return [for (final p in quad) center + (p - center) * factor];
}

Path quadPath(List<Offset> quad) => Path()..addPolygon(quad, true);
