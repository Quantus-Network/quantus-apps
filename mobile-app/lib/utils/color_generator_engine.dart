// gradient_id.dart
import 'dart:math';

import 'package:flutter/material.dart';

/// -------------------------------
/// Public API
/// -------------------------------

/// Color engine (perceptual OKLCH or classic HSV).
enum ColorEngine { oklch, hsv }

/// Hue spacing strategy (only used by HSV).
enum HueStrategy { golden, crystal }

/// All outputs you typically need for UI.
class AccountGradient {
  final Color colorA; // bright/top
  final Color colorB; // darker/bottom
  final RadialGradient radial;
  final LinearGradient linear;
  const AccountGradient({
    required this.colorA,
    required this.colorB,
    required this.radial,
    required this.linear,
  });
}

/// One-call entry point.
/// - Pick [engine]: ColorEngine.oklch (default) or ColorEngine.hsv
/// - For HSV, choose [hueStrategy]: golden (default) or crystal
/// - Tweak visual options via [options]
AccountGradient buildAccountGradient(
  String accountKey, {
  ColorEngine engine = ColorEngine.oklch,
  HueStrategy hueStrategy = HueStrategy.crystal,
  GradientOptions options = const GradientOptions(),
}) {
  final colors = switch (engine) {
    ColorEngine.oklch => _oklchColorsFromAccount(accountKey, options),
    ColorEngine.hsv => _hsvColorsFromAccount(accountKey, hueStrategy, options),
  };

  // Add a third “mid” stop to mimic your image’s soft band
  final mid = Color.lerp(colors.$1, colors.$2, options.midLerp)!;

  final radial = RadialGradient(
    center: Alignment(0, options.centerYOffset), // lift the glow
    radius: options.radius,
    colors: [colors.$1, mid, colors.$2],
    stops: [0.0, options.midStop, 1.0],
  );

  // Linear fallback/alt usage
  final rad = options.linearAngleDeg * pi / 180.0;
  final x = cos(rad), y = sin(rad);
  final linear = LinearGradient(
    begin: Alignment(-x, -y),
    end: Alignment(x, y),
    colors: [colors.$1, colors.$2],
  );

  return AccountGradient(
    colorA: colors.$1,
    colorB: colors.$2,
    radial: radial,
    linear: linear,
  );
}

/// Options that affect both color selection and gradient shaping.
class GradientOptions {
  // Gradient shape
  final double centerYOffset; // -0.32 ~ “glow from above”
  final double radius; // 0.9 looks good for circles
  final double midStop; // where the mid color stop lands (0..1)
  final double midLerp; // mix amount for mid color (0..1)
  final double linearAngleDeg;

  // HSV parameters (if engine == hsv)
  final double hsvSaturation;
  final double hsvValueTop;
  final double hsvValueBottom;
  final double hsvMinSpreadDeg;
  final double hsvMaxSpreadDeg;

  // OKLCH parameters (if engine == oklch)
  final double oklchChromaMin;
  final double oklchChromaMax;
  final double oklchLightTopMin;
  final double oklchLightTopMax;
  final double oklchLightBotMin;
  final double oklchLightBotMax;
  final double oklchMinSpreadDeg;
  final double oklchMaxSpreadDeg;

  const GradientOptions({
    this.centerYOffset = -0.32,
    this.radius = 0.9,
    this.midStop = 0.58,
    this.midLerp = 0.60,
    this.linearAngleDeg = 90, // 90 is top to bottom gradient
    // HSV default look (good on dark UI)
    this.hsvSaturation = 0.65,
    this.hsvValueTop = 0.96,
    this.hsvValueBottom = 0.80,
    this.hsvMinSpreadDeg = 40,
    this.hsvMaxSpreadDeg = 90,

    // OKLCH defaults: vivid but safe; pleasant lightness split
    this.oklchChromaMin = 0.20,
    this.oklchChromaMax = 0.26,
    this.oklchLightTopMin = 0.68,
    this.oklchLightTopMax = 0.74,
    this.oklchLightBotMin = 0.60,
    this.oklchLightBotMax = 0.66,
    this.oklchMinSpreadDeg = 40,
    this.oklchMaxSpreadDeg = 90,
  });
}

/// Quick helper: choose white/black text for contrast over the *center* of the radial.
Color readableOnCenter(AccountGradient g, {double thresholdL = 0.70}) {
  // Estimate luminance by converting center mix (mid) to relative luminance.
  final mid = Color.lerp(g.colorA, g.colorB, 0.5)!;
  final l = _relativeLuminance(mid);
  return l < thresholdL ? Colors.white : Colors.black;
}

/// -------------------------------
/// Implementation
/// -------------------------------

/// Stable 32-bit hash (FNV-1a)
int _fnv1a32(String input) {
  const int p = 0x01000193;
  int h = 0x811C9DC5;
  for (final b in input.codeUnits) {
    h ^= b;
    h = (h * p) & 0xFFFFFFFF;
  }
  return h;
}

/// Tiny, fast PRNG
class _XorShift32 {
  int _x;
  _XorShift32(int seed) : _x = seed == 0 ? 0x12345678 : seed;
  double next() {
    int x = _x;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17);
    x ^= (x << 5) & 0xFFFFFFFF;
    _x = x & 0xFFFFFFFF;
    final v = (_x >>> 0) / 0x100000000;
    return v == 0 ? 0.5 : v;
  }
}

/// ---------------- HSV path ----------------

Color _hsv(double h, double s, double v) {
  final h6 = (h % 1.0) * 6.0;
  final i = h6.floor();
  final f = h6 - i;
  final p = v * (1.0 - s);
  final q = v * (1.0 - f * s);
  final t = v * (1.0 - (1.0 - f) * s);

  double r = 0, g = 0, b = 0;
  switch (i) {
    case 0:
      r = v;
      g = t;
      b = p;
      break;
    case 1:
      r = q;
      g = v;
      b = p;
      break;
    case 2:
      r = p;
      g = v;
      b = t;
      break;
    case 3:
      r = p;
      g = q;
      b = v;
      break;
    case 4:
      r = t;
      g = p;
      b = v;
      break;
    default:
      r = v;
      g = p;
      b = q;
      break; // i==5
  }
  int ch(double x) => (x.clamp(0.0, 1.0) * 255.0).round();
  return Color.fromARGB(255, ch(r), ch(g), ch(b));
}

(double, double) _hsvHues(
  _XorShift32 rng,
  HueStrategy strategy,
  double minSpreadDeg,
  double maxSpreadDeg,
) {
  final base = rng.next(); // 0..1
  final h1 = switch (strategy) {
    HueStrategy.golden => (base + 0.618033988749895) % 1.0, // golden step
    HueStrategy.crystal => (base * 2.0) % 1.0, // your “crystal spiral”
  };
  final spread =
      (minSpreadDeg + rng.next() * (maxSpreadDeg - minSpreadDeg)) / 360.0;
  final h2 = (h1 + spread) % 1.0;
  return (h1, h2);
}

(Color, Color) _hsvColorsFromAccount(
  String accountKey,
  HueStrategy strategy,
  GradientOptions opt,
) {
  final rng = _XorShift32(_fnv1a32(accountKey));
  final (h1, h2) = _hsvHues(
    rng,
    strategy,
    opt.hsvMinSpreadDeg,
    opt.hsvMaxSpreadDeg,
  );
  final a = _hsv(h1, opt.hsvSaturation, opt.hsvValueTop);
  final b = _hsv(h2, opt.hsvSaturation, opt.hsvValueBottom);
  return (a, b);
}

/// ---------------- OKLCH path ----------------

class _OKLCH {
  final double L, C, h;
  const _OKLCH(this.L, this.C, this.h);
}

Color _oklchToColor(_OKLCH c) {
  double L = c.L, C = c.C, hRad = c.h * pi / 180.0;

  Color convert(double L, double C, double hRad) {
    final a = C * cos(hRad);
    final b = C * sin(hRad);

    final l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = L - 0.0894841775 * a - 1.2914855480 * b;

    final l = l_ * l_ * l_;
    final m = m_ * m_ * m_;
    final s = s_ * s_ * s_;

    double r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    double g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    double b2 = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

    double compand(double v) =>
        v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055;

    r = compand(r.clamp(0.0, 1.0));
    g = compand(g.clamp(0.0, 1.0));
    b2 = compand(b2.clamp(0.0, 1.0));

    int ch(double x) => (x * 255.0).clamp(0.0, 255.0).round();
    return Color.fromARGB(255, ch(r), ch(g), ch(b2));
  }

  // Gentle gamut clip by reducing C a few steps if needed
  double chromaWorking = C;
  Color out = convert(L, chromaWorking, hRad);
  for (int i = 0; i < 6; i++) {
    final test = convert(L, chromaWorking, hRad);
    if (test == out) break;
    out = test;
    chromaWorking *= 0.92;
  }
  return out;
}

(Color, Color) _oklchColorsFromAccount(String accountKey, GradientOptions opt) {
  final rng = _XorShift32(_fnv1a32(accountKey));

  final h1 = rng.next() * 360.0;
  final spread =
      opt.oklchMinSpreadDeg +
      rng.next() * (opt.oklchMaxSpreadDeg - opt.oklchMinSpreadDeg);
  final h2 = (h1 + spread) % 360.0;

  final C =
      opt.oklchChromaMin +
      rng.next() * (opt.oklchChromaMax - opt.oklchChromaMin);

  final lightTop =
      opt.oklchLightTopMin +
      rng.next() * (opt.oklchLightTopMax - opt.oklchLightTopMin);
  final lightBottom =
      opt.oklchLightBotMin +
      rng.next() * (opt.oklchLightBotMax - opt.oklchLightBotMin);

  final a = _oklchToColor(_OKLCH(lightTop, C, h1));
  final b = _oklchToColor(_OKLCH(lightBottom, C, h2));
  return (a, b);
}

/// ---------------- Utilities ----------------

double _relativeLuminance(Color c) {
  double linFromNormalized(double v) {
    return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linFromNormalized(c.r);
  final g = linFromNormalized(c.g);
  final b = linFromNormalized(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
