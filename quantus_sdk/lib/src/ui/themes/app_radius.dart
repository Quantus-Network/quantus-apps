import 'package:flutter/material.dart';

/// Quantus App v3 radius tokens, mapped 1:1 from Figma SYSTEM / Radius & Rules.
///
/// Mobile-app law. Web surfaces stay zero-radius.
@immutable
class AppRadiusV3 extends ThemeExtension<AppRadiusV3> {
  /// Tags, micro elements. Figma r-xs.
  final double xs;

  /// Chips, small tiles. Figma r-sm.
  final double sm;

  /// Buttons, inputs, cards, rows. Figma r-md.
  final double md;

  /// Bottom sheets, modals. Figma r-lg.
  final double lg;

  /// Full-round CTAs (height/2). Figma pill.
  final double pill;

  const AppRadiusV3({required this.xs, required this.sm, required this.md, required this.lg, required this.pill});

  /// Mobile radius scale from Figma SYSTEM / Radius Tokens.
  const AppRadiusV3.standard() : this(xs: 4, sm: 8, md: 14, lg: 32, pill: 36);

  BorderRadius get xsBorder => BorderRadius.circular(xs);
  BorderRadius get smBorder => BorderRadius.circular(sm);
  BorderRadius get mdBorder => BorderRadius.circular(md);
  BorderRadius get lgBorder => BorderRadius.circular(lg);
  BorderRadius get pillBorder => BorderRadius.circular(pill);

  @override
  AppRadiusV3 copyWith({double? xs, double? sm, double? md, double? lg, double? pill}) {
    return AppRadiusV3(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadiusV3 lerp(AppRadiusV3? other, double t) {
    if (other is! AppRadiusV3) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppRadiusV3(
      xs: l(xs, other.xs),
      sm: l(sm, other.sm),
      md: l(md, other.md),
      lg: l(lg, other.lg),
      pill: l(pill, other.pill),
    );
  }
}

extension AppRadiusV3Extension on BuildContext {
  AppRadiusV3 get radiusV3 => Theme.of(this).extension<AppRadiusV3>()!;
}
