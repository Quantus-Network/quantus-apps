import 'dart:math';

import 'package:flutter/material.dart';

// Classes to generate gradients deterministically from an account (or any hash)

// USAGE
// final grad = radialAccountGradient('user123:acct2');

// Container(
//   width: 120,
//   height: 120,
//   decoration: BoxDecoration(
//     shape: BoxShape.circle,
//     gradient: grad,
//   ),
// );

/// ---------- 1) Stable 32-bit hash (FNV-1a) ----------
int fnv1a32(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811C9DC5;
  for (final b in input.codeUnits) {
    hash ^= b;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// ---------- 2) Tiny PRNG (xorshift32) ----------
class XorShift32 {
  int _x;
  XorShift32(int seed) : _x = seed == 0 ? 0x12345678 : seed;

  /// returns 0.0 .. 1.0 (exclusive of 1.0)
  double next() {
    int x = _x;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    _x = x & 0xFFFFFFFF;
    final v = (_x >>> 0) / 0x100000000;
    return v == 0.0 ? 0.5 : v;
  }
}

/// ---------- 3) OKLCH -> sRGB Color ----------
class OKLCH {
  final double L; // 0..1
  final double C; // ~0..0.4 usable
  final double h; // degrees
  const OKLCH(this.L, this.C, this.h);
}

/// Convert OKLCH to Color (sRGB), with gentle gamut clipping by reducing C.
Color oklchToColor(OKLCH c) {
  double lightness = c.L, chroma = c.C, hRad = c.h * pi / 180.0;

  Color tryConvert(double lightness, double chroma, double hRad) {
    final a = chroma * cos(hRad);
    final b = chroma * sin(hRad);

    // Oklab -> LMS'
    final l_ = lightness + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = lightness - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = lightness - 0.0894841775 * a - 1.2914855480 * b;

    // Cube to LMS
    final l = l_ * l_ * l_;
    final m = m_ * m_ * m_;
    final s = s_ * s_ * s_;

    // LMS -> linear sRGB
    double r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    double g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    double b2 = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

    // in-gamut check (linear) — not used directly, kept for reference
    // final bool
    // ok = r >= 0 && g >= 0 && b2 >= 0 && r <= 1 && g <= 1 && b2 <= 1;

    // sRGB gamma companding
    double compand(double v) => v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055;

    r = compand(r.clamp(0.0, 1.0));
    g = compand(g.clamp(0.0, 1.0));
    b2 = compand(b2.clamp(0.0, 1.0));

    return Color.fromARGB(
      0xFF,
      (r * 255 + 0.5).floor().clamp(0, 255),
      (g * 255 + 0.5).floor().clamp(0, 255),
      (b2 * 255 + 0.5).floor().clamp(0, 255),
    );
  }

  // Gentle gamut clip: reduce chroma until it fits (usually a couple steps).
  double cWork = chroma;
  Color out = tryConvert(lightness, cWork, hRad);
  for (int i = 0; i < 8; i++) {
    // quick probe: if any channel got clipped hard, back off chroma
    // (We can’t see linear channels here; heuristic: reduce C slightly.)
    final before = out;
    cWork *= 0.92;
    final test = tryConvert(lightness, cWork, hRad);
    // If color changed notably, keep; otherwise break early
    if (test.toARGB32() == before.toARGB32()) break;
    out = test;
  }
  return out;
}

/// ---------- 4) Hash -> two OKLCH colors (nice for dark UI) ----------
class GradientColors {
  final Color a; // primary/top color
  final Color b; // secondary/bottom color
  final Color? h; // optional highlight for radial center
  const GradientColors(this.a, this.b, {this.h});
}

GradientColors colorsFromAccountId(String id) {
  final seed = fnv1a32(id);
  final rng = XorShift32(seed);

  // Primary hue and an even larger spread for stronger contrast
  // (near complementary)
  final h1 = rng.next() * 360.0;
  final spread = 160.0 + rng.next() * 40.0; // 160–200°
  final h2 = (h1 + spread) % 360.0;

  // Higher chroma for pop, with slight asymmetry.
  // Gamut clipping in oklchToColor will keep it displayable.
  final baseC = 0.38 + rng.next() * 0.18; // 0.38–0.56
  final deltaC = (rng.next() * 0.12) - 0.06; // -0.06..+0.06
  final c1 = (baseC + deltaC).clamp(0.26, 0.52);
  final c2 = (baseC - deltaC).clamp(0.26, 0.52);

  // Widen brightness separation to emphasize gradient.
  final l1 = 0.78 + rng.next() * 0.08; // 0.78–0.86
  final l2 = 0.48 + rng.next() * 0.08; // 0.48–0.56

  final colorA = oklchToColor(OKLCH(l1, c1, h1));
  final colorB = oklchToColor(OKLCH(l2, c2, h2));

  // Subtle OKLCH highlight near center to mimic demo's glossy look
  final highlight = oklchToColor(OKLCH((l1 + 0.12).clamp(0.0, 1.0), max(0.02, c1 * 0.12), h1));

  return GradientColors(colorA, colorB, h: highlight);
}

/// ---------- 5) Ready-made gradients ----------
/// Like your screenshot: a circular radial gradient with the "light"
/// slightly above center.
RadialGradient radialAccountGradient(String accountId) {
  final gc = colorsFromAccountId(accountId);
  return RadialGradient(
    center: const Alignment(0, -0.28), // slight top highlight
    radius: 1.0,
    colors: [gc.h ?? gc.a, gc.a, gc.b],
    stops: const [0.0, 0.38, 1.0],
  );
}

/// Linear alternative (e.g., for bars or headers).
LinearGradient linearAccountGradient(String accountId, {double angleDeg = 90}) {
  final gc = colorsFromAccountId(accountId);
  final rad = angleDeg * pi / 180.0;
  final x = cos(rad), y = sin(rad);
  return LinearGradient(begin: Alignment(-x, -y), end: Alignment(x, y), colors: [gc.a, gc.b]);
}
