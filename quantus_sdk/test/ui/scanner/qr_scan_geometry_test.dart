import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/ui/components/scanner/qr_scan_geometry.dart';

void main() {
  const capture = Size(1280, 720);

  test('cover-fit scaling crops the wider axis symmetrically', () {
    final mapped = mapCornersToPreview(
      const [Offset(640, 360), Offset(0, 0), Offset(1280, 720), Offset(640, 0)],
      capture,
      const Size(640, 480),
    );
    expect(mapped[0].dx, closeTo(320, 0.01));
    expect(mapped[0].dy, closeTo(240, 0.01));
    expect(mapped[1].dx, closeTo(-106.67, 0.01));
    expect(mapped[1].dy, closeTo(0, 0.01));
    expect(mapped[2].dx, closeTo(746.67, 0.01));
    expect(mapped[2].dy, closeTo(480, 0.01));
  });

  test('cover-fit scaling crops the taller axis for a square preview', () {
    final mapped = mapCornersToPreview(
      const [Offset(0, 0), Offset(1280, 0), Offset(1280, 720), Offset(0, 720)],
      capture,
      const Size(400, 400),
    );
    expect(mapped[0].dx, closeTo(-155.56, 0.01));
    expect(mapped[0].dy, closeTo(0, 0.01));
    expect(mapped[2].dx, closeTo(555.56, 0.01));
    expect(mapped[2].dy, closeTo(400, 0.01));
  });

  test('mirrored previews flip x about the preview width', () {
    final plain = mapCornersToPreview(
      const [Offset(100, 100), Offset(200, 100), Offset(200, 200), Offset(100, 200)],
      capture,
      capture,
    );
    final mirrored = mapCornersToPreview(
      const [Offset(100, 100), Offset(200, 100), Offset(200, 200), Offset(100, 200)],
      capture,
      capture,
      mirrored: true,
    );
    for (var i = 0; i < 4; i++) {
      expect(mirrored[i].dx, closeTo(1280 - plain[i].dx, 0.01));
      expect(mirrored[i].dy, closeTo(plain[i].dy, 0.01));
    }
  });

  test('degenerate input maps to nothing', () {
    expect(mapCornersToPreview(const [Offset.zero], capture, capture), isEmpty);
    expect(
      mapCornersToPreview(const [Offset.zero, Offset.zero, Offset.zero, Offset.zero], Size.zero, capture),
      isEmpty,
    );
    expect(normalizeQuad(const [Offset.zero, Offset.zero, Offset.zero]), isEmpty);
  });

  test('normalizeQuad gives the same order for any rotation or permutation of the corners', () {
    const square = [Offset(10, 10), Offset(50, 10), Offset(50, 50), Offset(10, 50)];
    final expected = normalizeQuad(square);
    expect(expected.first, const Offset(10, 10));
    for (var rotation = 0; rotation < 4; rotation++) {
      final rotated = [for (var i = 0; i < 4; i++) square[(i + rotation) % 4]];
      expect(normalizeQuad(rotated), expected);
      expect(normalizeQuad(rotated.reversed.toList()), expected);
    }
  });

  test('the device highlight follows the code and stays inside the preview', () {
    const preview = Size(640, 480);
    final device = deviceHighlightRect(const [
      Offset(300, 200),
      Offset(380, 200),
      Offset(380, 280),
      Offset(300, 280),
    ], preview);
    expect(device.size.width, closeTo(104, 0.01));
    expect(device.size.height, closeTo(192, 0.01));
    expect(device.center, const Offset(340, 240));
    expect(device.angle, closeTo(0, 1e-9));
    expect(device.radius, 12);

    final edge = deviceHighlightRect(const [
      Offset(600, 440),
      Offset(680, 440),
      Offset(680, 520),
      Offset(600, 520),
    ], preview);
    expect(edge.center.dx + edge.size.width / 2, lessThanOrEqualTo(preview.width - 8));
    expect(edge.center.dy + edge.size.height / 2, lessThanOrEqualTo(preview.height - 8));

    final huge = deviceHighlightRect(const [Offset(0, 0), Offset(600, 0), Offset(600, 600), Offset(0, 600)], preview);
    expect(huge.size.width, preview.width - 16);
    expect(huge.size.height, preview.height - 16);
  });

  test('a rotated code rotates the device highlight', () {
    final tilted = deviceHighlightRect(const [
      Offset(100, 100),
      Offset(170, 170),
      Offset(100, 240),
      Offset(30, 170),
    ], const Size(640, 480));
    expect(tilted.angle, closeTo(math.pi / 4, 1e-9));
    final bounds = tilted.toPath().getBounds();
    expect(bounds.center.dx, closeTo(100, 0.5));
    expect(bounds.center.dy, closeTo(170, 0.5));
  });

  test('scaleQuad keeps the centre', () {
    const square = [Offset(10, 10), Offset(50, 10), Offset(50, 50), Offset(10, 50)];
    final scaled = scaleQuad(square, 0.5);
    expect(quadCenter(scaled), quadCenter(square));
    expect(scaled[0], const Offset(20, 20));
  });
}
