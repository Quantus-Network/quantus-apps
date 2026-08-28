import 'package:flutter/material.dart';

/// Quantus App v3 color tokens, mapped 1:1 from Figma SYSTEM / Color Tokens.
///
/// Do not add colors that are not in the Figma table. Derive alpha with [Color.useOpacity]
/// at the call site when a widget needs a tint of an existing token.
@immutable
class AppColorsV3 extends ThemeExtension<AppColorsV3> {
  /// Screen background. Every screen base. Nothing else.
  final Color bgVoid;

  /// Anything on the screen: cards, sheets, rows. This is elevation.
  final Color bgSurface;

  /// Anything on a surface: inputs in cards, skeletons, disabled CTAs.
  final Color bgSurface2;

  /// Anything on a surface but glassy: inputs in cards, skeletons, disabled CTAs.
  final Color bgSurfaceGlass;

  /// Default text. Titles, amounts, body. Warm, not pure white.
  final Color textContent;

  /// Void text. Used for text on accent color.
  final Color textVoid;

  /// Secondary. Darkest gray legal on small text (AA floor).
  final Color textMuted;

  /// Tertiary. Large or decorative only. Never on small labels.
  final Color textMuted2;

  /// Rare deliberate emphasis. Using it often means something is wrong.
  final Color textWhite;

  /// Actions, prominent colors, and CTAs only.
  final Color accentFlare;

  /// Settles. Success, confirmed, guaranteed minimum, funds safe.
  final Color semanticSage;

  /// Warns. Expired, attention, advisory. Not an error.
  final Color semanticSand;

  /// Fails. Errors, destructive actions. Large text only on dark.
  final Color semanticEmber;

  /// Waits. Pending, suspended, reversible, in-between.
  final Color semanticGlacier;

  /// Checkphrases and recovery/mnemonic words. Nothing else wears lilac.
  final Color semanticLilac;

  /// Default border. All cards, rows, dividers. White at 7%.
  final Color borderHairline;

  /// Selected or focused containers. The loudest border allowed. White at 12%.
  final Color borderEmphasis;

  const AppColorsV3({
    required this.bgVoid,
    required this.bgSurface,
    required this.bgSurface2,
    required this.bgSurfaceGlass,
    required this.textContent,
    required this.textVoid,
    required this.textMuted,
    required this.textMuted2,
    required this.textWhite,
    required this.accentFlare,
    required this.semanticSage,
    required this.semanticSand,
    required this.semanticEmber,
    required this.semanticGlacier,
    required this.semanticLilac,
    required this.borderHairline,
    required this.borderEmphasis,
  });

  /// Dark palette from Figma SYSTEM / Color Tokens (Table).
  ///
  /// Border alphas match [Color.useOpacity]: 7% → `0x12`, 12% → `0x1F`.
  const AppColorsV3.dark()
    : this(
        bgVoid: const Color(0xFF0E0E0E),
        bgSurface: const Color(0xFF181818),
        bgSurface2: const Color(0xFF222222),
        bgSurfaceGlass: const Color(0x1AFFFFFF),
        textContent: const Color(0xFFE8E6E0),
        textVoid: const Color(0xFF0E0E0E),
        textMuted: const Color(0xFF8A8784),
        textMuted2: const Color(0xFF6B6966),
        textWhite: const Color(0xFFFFFFFF),
        accentFlare: const Color(0xFFFF6B35),
        semanticSage: const Color(0xFF6DBF8A),
        semanticSand: const Color(0xFFD9BC8A),
        semanticEmber: const Color(0xFFC94F3A),
        semanticGlacier: const Color(0xFFA8D8E8),
        semanticLilac: const Color(0xFFC4B1FC),
        borderHairline: const Color(0x12FFFFFF),
        borderEmphasis: const Color(0x1FFFFFFF),
      );

  @override
  AppColorsV3 copyWith({
    Color? bgVoid,
    Color? bgSurface,
    Color? bgSurface2,
    Color? bgSurfaceGlass,
    Color? textContent,
    Color? textVoid,
    Color? textMuted,
    Color? textMuted2,
    Color? textWhite,
    Color? accentFlare,
    Color? semanticSage,
    Color? semanticSand,
    Color? semanticEmber,
    Color? semanticGlacier,
    Color? semanticLilac,
    Color? borderHairline,
    Color? borderEmphasis,
  }) {
    return AppColorsV3(
      bgVoid: bgVoid ?? this.bgVoid,
      bgSurface: bgSurface ?? this.bgSurface,
      bgSurface2: bgSurface2 ?? this.bgSurface2,
      bgSurfaceGlass: bgSurfaceGlass ?? this.bgSurfaceGlass,
      textContent: textContent ?? this.textContent,
      textVoid: textVoid ?? this.textVoid,
      textMuted: textMuted ?? this.textMuted,
      textMuted2: textMuted2 ?? this.textMuted2,
      textWhite: textWhite ?? this.textWhite,
      accentFlare: accentFlare ?? this.accentFlare,
      semanticSage: semanticSage ?? this.semanticSage,
      semanticSand: semanticSand ?? this.semanticSand,
      semanticEmber: semanticEmber ?? this.semanticEmber,
      semanticGlacier: semanticGlacier ?? this.semanticGlacier,
      semanticLilac: semanticLilac ?? this.semanticLilac,
      borderHairline: borderHairline ?? this.borderHairline,
      borderEmphasis: borderEmphasis ?? this.borderEmphasis,
    );
  }

  @override
  AppColorsV3 lerp(AppColorsV3? other, double t) {
    if (other is! AppColorsV3) return this;
    return AppColorsV3(
      bgVoid: Color.lerp(bgVoid, other.bgVoid, t) ?? bgVoid,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t) ?? bgSurface,
      bgSurface2: Color.lerp(bgSurface2, other.bgSurface2, t) ?? bgSurface2,
      bgSurfaceGlass: Color.lerp(bgSurfaceGlass, other.bgSurfaceGlass, t) ?? bgSurfaceGlass,
      textContent: Color.lerp(textContent, other.textContent, t) ?? textContent,
      textVoid: Color.lerp(textVoid, other.textVoid, t) ?? textVoid,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textMuted2: Color.lerp(textMuted2, other.textMuted2, t) ?? textMuted2,
      textWhite: Color.lerp(textWhite, other.textWhite, t) ?? textWhite,
      accentFlare: Color.lerp(accentFlare, other.accentFlare, t) ?? accentFlare,
      semanticSage: Color.lerp(semanticSage, other.semanticSage, t) ?? semanticSage,
      semanticSand: Color.lerp(semanticSand, other.semanticSand, t) ?? semanticSand,
      semanticEmber: Color.lerp(semanticEmber, other.semanticEmber, t) ?? semanticEmber,
      semanticGlacier: Color.lerp(semanticGlacier, other.semanticGlacier, t) ?? semanticGlacier,
      semanticLilac: Color.lerp(semanticLilac, other.semanticLilac, t) ?? semanticLilac,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t) ?? borderHairline,
      borderEmphasis: Color.lerp(borderEmphasis, other.borderEmphasis, t) ?? borderEmphasis,
    );
  }
}

extension AppColorsV3Extension on BuildContext {
  AppColorsV3 get colorsV3 => Theme.of(this).extension<AppColorsV3>()!;
}
