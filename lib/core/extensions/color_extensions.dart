import 'dart:ui';

extension ColorOpacityExtension on Color {
  /// Returns a new color that is a blend of this color and the given [opacity].
  ///
  /// The [opacity] argument must be between 0.0 and 1.0 (inclusive).
  /// An opacity of 1.0 is fully opaque, and 0.0 is fully transparent.
  Color useOpacity(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withValues(alpha: opacity * 255);
  }
}
