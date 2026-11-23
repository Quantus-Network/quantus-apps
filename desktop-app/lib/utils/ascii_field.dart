import 'dart:math' as math;

/// The characters of the field, from empty to densest. A pattern line is
/// drawn with the last one.
const asciiRamp = ' .,·:;|+x#';

/// How close to a pattern line a point must be to be drawn as part of it.
const _lineWidth = 0.12;

/// The wave modes the cursor moves through.
const _waveModes = [(1, 2), (2, 1), (2, 3), (3, 2), (1, 3), (3, 1), (2, 4), (4, 2), (3, 3), (3, 4), (4, 3)];

/// How far a square plate vibrating in wave mode ([m], [n]) is displaced at
/// ([px], [py]), each from -1 to 1. Sand on such a plate gathers where this
/// is zero: the lines of a Chladni figure.
///
/// The figure is the mix of two modes, and [t] moves the mix slowly back and
/// forth, which makes the figure breathe.
double chladniRect(double px, double py, int m, int n, double t) {
  final x = (px + 1) / 2;
  final y = (py + 1) / 2;
  final a = math.sin(m * math.pi * x) * math.sin(n * math.pi * y);
  final b = math.sin(n * math.pi * x) * math.sin(m * math.pi * y);
  return a + math.cos(t * 0.18) * b;
}

/// The Chladni figure of wave mode ([m], [n]) at time [t] as [rows] lines of
/// [cols] characters, joined by newlines.
///
/// With [reveal] the figure is drawn only inside a circle around the centre,
/// which covers the whole field once [reveal] passes about 1.3.
///
/// This is the website's `renderASCIIRect`, so both draw the same field.
String renderAsciiField({
  required int m,
  required int n,
  required double t,
  required int cols,
  required int rows,
  double? reveal,
}) {
  // [chladniRect], with everything that is the same along a column, along a
  // row or across the whole field worked out once. A full window is some ten
  // thousand characters, redrawn every frame.
  double wave(int mode, int index, int count) => math.sin(mode * math.pi * (((index / count) * 2 - 1) + 1) / 2);
  final sinMx = [for (var col = 0; col < cols; col++) wave(m, col, cols)];
  final sinNx = [for (var col = 0; col < cols; col++) wave(n, col, cols)];
  final mix = math.cos(t * 0.18);

  final lines = <String>[];
  final line = StringBuffer();
  for (var row = 0; row < rows; row++) {
    line.clear();
    final py = (row / rows) * 2 - 1;
    final sinNy = wave(n, row, rows);
    final sinMy = wave(m, row, rows);
    for (var col = 0; col < cols; col++) {
      final px = (col / cols) * 2 - 1;
      if (reveal != null && math.sqrt(px * px + py * py) > reveal * 1.08) {
        line.write(' ');
        continue;
      }

      final distance = (sinMx[col] * sinNy + mix * sinNx[col] * sinMy).abs();
      final index = distance < _lineWidth
          ? ((1 - distance / _lineWidth) * (asciiRamp.length - 1)).floor()
          : (((0.4 - distance) / 0.4) * 2).floor();
      line.write(asciiRamp[index.clamp(0, asciiRamp.length - 1)]);
    }
    lines.add(line.toString());
  }
  return lines.join('\n');
}

/// The wave mode for a cursor at ([nx], [ny]), each from 0 at the window's
/// top left to 1 at its bottom right.
(int, int) waveModeAt(double nx, double ny) {
  return _waveModes[(nx * ny * _waveModes.length * 3.1).floor() % _waveModes.length];
}
