import 'package:flutter/material.dart';

@immutable
class AppColorsV2 extends ThemeExtension<AppColorsV2> {
  // Backgrounds
  final Color background;
  final Color backgroundAlt;
  final Color toasterBackground;

  // Surfaces
  final Color surface;
  final Color surfaceGlass;
  final Color surfaceCard;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textError;

  // Accents
  final Color accentGreen;
  final Color accentPink;
  final Color checksum;

  // Semantic
  final Color error;
  final Color danger;
  final Color success;

  // Glow & Gradients
  final Color backgroundGlow;
  final List<Color> buttonPrimaryGradient;

  // UI elements
  final Color separator;
  final Color txItemSeparator;
  final Color border;
  final Color buttonDisabled;
  final Color buttonDanger;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color toasterBorder;
  final Color sheetBackground;
  final Color borderSubtle;
  final Color borderDanger;

  // Account tags
  final Color tagGuardian;
  final Color tagEntrusted;
  final Color tagHighSecurity;

  const AppColorsV2({
    required this.background,
    required this.backgroundAlt,
    required this.toasterBackground,
    required this.toasterBorder,
    required this.sheetBackground,
    required this.borderSubtle,
    required this.borderDanger,
    required this.surface,
    required this.surfaceGlass,
    required this.surfaceCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textError,
    required this.accentGreen,
    required this.accentPink,
    required this.checksum,
    required this.error,
    required this.danger,
    required this.success,
    required this.backgroundGlow,
    required this.buttonPrimaryGradient,
    required this.separator,
    required this.txItemSeparator,
    required this.border,
    required this.buttonDisabled,
    required this.buttonDanger,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.tagGuardian,
    required this.tagEntrusted,
    required this.tagHighSecurity,
  });

  const AppColorsV2.dark()
    : this(
        background: const Color(0xFF141414),
        backgroundAlt: const Color(0xFF1F1F1F),
        toasterBackground: const Color(0xFF191919),
        toasterBorder: const Color(0xFF3D3D3D),
        sheetBackground: const Color(0xFF1A1A1A),
        borderSubtle: const Color(0x70FFFFFF),
        borderDanger: const Color(0x70FF0000),
        surface: const Color(0xFF292929),
        surfaceGlass: const Color(0x1AFFFFFF),
        surfaceCard: const Color(0x0FFFFFFF),
        textPrimary: const Color(0xFFFFFFFF),
        textSecondary: const Color(0x80FFFFFF),
        textTertiary: const Color(0x52FFFFFF),
        textError: const Color(0xFFFF5252),
        accentGreen: const Color(0xFF34C759),
        accentPink: const Color(0xFFED4CCE),
        checksum: const Color(0xFF4CEDE7),
        error: const Color(0xFFFF2D54),
        danger: const Color(0xFFFF1F45),
        success: const Color(0xFF1FFFA7),
        backgroundGlow: const Color(0xFFFFFFFF),
        buttonPrimaryGradient: const [Color(0xFF0000FF), Color(0xFFED4CCE)],
        separator: const Color(0x1AFFFFFF),
        txItemSeparator: const Color(0x05FFFFFF),
        border: const Color(0x33FFFFFF),
        buttonDisabled: const Color(0xFF3D3C44),
        buttonDanger: const Color(0x1AFF0000),
        skeletonBase: const Color(0xFF3D3C44),
        skeletonHighlight: const Color(0xFF5A5A5A),
        tagGuardian: const Color(0xFF9747FF),
        tagEntrusted: const Color(0xFFFFD541),
        tagHighSecurity: const Color(0xFF4CEDE7),
      );

  @override
  AppColorsV2 copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceGlass,
    Color? surfaceCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textError,
    Color? accentGreen,
    Color? accentPink,
    Color? checksum,
    Color? error,
    Color? danger,
    Color? success,
    Color? backgroundGlow,
    List<Color>? buttonPrimaryGradient,
    Color? separator,
    Color? txItemSeparator,
    Color? border,
    Color? toasterBackground,
    Color? toasterBorder,
    Color? sheetBackground,
    Color? borderSubtle,
    Color? buttonDisabled,
    Color? buttonDanger,
    Color? borderDanger,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? tagGuardian,
    Color? tagEntrusted,
    Color? tagHighSecurity,
  }) {
    return AppColorsV2(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      toasterBackground: toasterBackground ?? this.toasterBackground,
      toasterBorder: toasterBorder ?? this.toasterBorder,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surface: surface ?? this.surface,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textError: textError ?? this.textError,
      accentGreen: accentGreen ?? this.accentGreen,
      accentPink: accentPink ?? this.accentPink,
      checksum: checksum ?? this.checksum,
      error: error ?? this.error,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      buttonPrimaryGradient: buttonPrimaryGradient ?? this.buttonPrimaryGradient,
      separator: separator ?? this.separator,
      txItemSeparator: txItemSeparator ?? this.txItemSeparator,
      border: border ?? this.border,
      buttonDisabled: buttonDisabled ?? this.buttonDisabled,
      buttonDanger: buttonDanger ?? this.buttonDanger,
      borderDanger: borderDanger ?? this.borderDanger,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      tagGuardian: tagGuardian ?? this.tagGuardian,
      tagEntrusted: tagEntrusted ?? this.tagEntrusted,
      tagHighSecurity: tagHighSecurity ?? this.tagHighSecurity,
    );
  }

  @override
  AppColorsV2 lerp(AppColorsV2? other, double t) {
    if (other is! AppColorsV2) return this;
    return AppColorsV2(
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t) ?? backgroundAlt,
      toasterBackground: Color.lerp(toasterBackground, other.toasterBackground, t) ?? toasterBackground,
      toasterBorder: Color.lerp(toasterBorder, other.toasterBorder, t) ?? toasterBorder,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t) ?? sheetBackground,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t) ?? surfaceGlass,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      textError: Color.lerp(textError, other.textError, t) ?? textError,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t) ?? accentGreen,
      accentPink: Color.lerp(accentPink, other.accentPink, t) ?? accentPink,
      checksum: Color.lerp(checksum, other.checksum, t) ?? checksum,
      error: Color.lerp(error, other.error, t) ?? error,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      success: Color.lerp(success, other.success, t) ?? success,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t) ?? backgroundGlow,
      buttonPrimaryGradient: other.buttonPrimaryGradient,
      separator: Color.lerp(separator, other.separator, t) ?? separator,
      txItemSeparator: Color.lerp(txItemSeparator, other.txItemSeparator, t) ?? txItemSeparator,
      border: Color.lerp(border, other.border, t) ?? border,
      buttonDisabled: Color.lerp(buttonDisabled, other.buttonDisabled, t) ?? buttonDisabled,
      buttonDanger: Color.lerp(buttonDanger, other.buttonDanger, t) ?? buttonDanger,
      borderDanger: Color.lerp(borderDanger, other.borderDanger, t) ?? borderDanger,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t) ?? skeletonBase,
      skeletonHighlight: Color.lerp(skeletonHighlight, other.skeletonHighlight, t) ?? skeletonHighlight,
      tagGuardian: Color.lerp(tagGuardian, other.tagGuardian, t) ?? tagGuardian,
      tagEntrusted: Color.lerp(tagEntrusted, other.tagEntrusted, t) ?? tagEntrusted,
      tagHighSecurity: Color.lerp(tagHighSecurity, other.tagHighSecurity, t) ?? tagHighSecurity,
    );
  }
}

extension AppColorsV2Extension on BuildContext {
  AppColorsV2 get colors => Theme.of(this).extension<AppColorsV2>()!;
}
