import 'package:flutter/material.dart';

@immutable
class AppColorsV2 extends ThemeExtension<AppColorsV2> {
  // Backgrounds
  final Color background;

  // Surfaces
  final Color surface;
  final Color surfaceGlass;
  final Color surfaceCard;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color textError;
  final Color textLabel;
  final Color textLightGray;

  // Accents
  final Color accentOrange;
  final Color accentGreen;
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
  final Color txItemIncomingHighlightBg;
  final Color txItemOutgoingHighlightBg;
  final Color txItemOutgoingHighlightBorder;
  final Color txItemIconDefault;
  final Color txItemIncomingHighlightBorder;
  final Color txItemBorderDefault;
  final Color border;
  final Color buttonDisabled;
  final Color buttonDanger;
  final Color skeletonBase;
  final Color skeletonHighlightA;
  final Color skeletonHighlightB;
  final Color toasterBorder;
  final Color toasterBackground;
  final Color sheetBackground;
  final Color borderButton;
  final Color borderSubtle;
  final Color borderDanger;

  // Segmented control
  final Color segmentedControlPill;

  // Receive screen
  final Color surfaceDeep;
  final Color copyButtonCopiedBg;
  final Color copyButtonCopiedBorder;

  // Account tags
  final Color tagGuardian;
  final Color tagEntrusted;
  final Color tagHighSecurity;

  const AppColorsV2({
    required this.background,
    required this.toasterBackground,
    required this.toasterBorder,
    required this.sheetBackground,
    required this.borderSubtle,
    required this.borderDanger,
    required this.borderButton,
    required this.surface,
    required this.surfaceGlass,
    required this.surfaceCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.textError,
    required this.textLabel,
    required this.textLightGray,
    required this.accentOrange,
    required this.accentGreen,
    required this.checksum,
    required this.error,
    required this.danger,
    required this.success,
    required this.backgroundGlow,
    required this.buttonPrimaryGradient,
    required this.separator,
    required this.txItemSeparator,
    required this.txItemIncomingHighlightBg,
    required this.txItemOutgoingHighlightBg,
    required this.txItemOutgoingHighlightBorder,
    required this.txItemIconDefault,
    required this.txItemIncomingHighlightBorder,
    required this.txItemBorderDefault,
    required this.border,
    required this.buttonDisabled,
    required this.buttonDanger,
    required this.skeletonBase,
    required this.skeletonHighlightA,
    required this.skeletonHighlightB,
    required this.segmentedControlPill,
    required this.surfaceDeep,
    required this.copyButtonCopiedBg,
    required this.copyButtonCopiedBorder,
    required this.tagGuardian,
    required this.tagEntrusted,
    required this.tagHighSecurity,
  });

  const AppColorsV2.dark()
    : this(
        background: const Color(0xFF0E0E0E),
        toasterBackground: const Color(0xFF181818),
        toasterBorder: const Color(0xFF272727),
        sheetBackground: const Color(0xFF1A1A1A),
        border: const Color(0x33FFFFFF),
        borderSubtle: const Color(0x70FFFFFF),
        borderDanger: const Color(0x70FF0000),
        borderButton: const Color(0xFF272727),
        surface: const Color(0xFF292929),
        surfaceGlass: const Color(0x1AFFFFFF),
        surfaceCard: const Color(0x0FFFFFFF),
        textPrimary: const Color(0xFFFFFFFF),
        textSecondary: const Color(0x80FFFFFF),
        textTertiary: const Color(0xFF3D3D3D),
        textMuted: const Color(0xFF888888),
        textError: const Color(0xFFC0392B),
        textLabel: const Color(0xFF787878),
        textLightGray: const Color(0xFFEBEBEB),
        accentOrange: const Color(0xFFFF6B35),
        accentGreen: const Color(0xFF34C759),
        checksum: const Color(0xFF95A7FB),
        error: const Color(0xFFFF2D54),
        danger: const Color(0xFFFF1F45),
        success: const Color(0xFF22A27F),
        backgroundGlow: const Color(0xFFFFFFFF),
        buttonPrimaryGradient: const [Color(0xFF0000FF), Color(0xFFED4CCE)],
        separator: const Color(0x1AFFFFFF),
        txItemSeparator: const Color(0x7F272727),
        txItemIncomingHighlightBg: const Color(0x14408C6B),
        txItemOutgoingHighlightBg: const Color(0x1440618C),
        txItemOutgoingHighlightBorder: const Color(0x2640618C),
        txItemIconDefault: const Color(0xFF363636),
        txItemIncomingHighlightBorder: const Color(0x26408C6B),
        txItemBorderDefault: const Color(0xFF191919),
        segmentedControlPill: const Color(0xFF1C1C1C),
        surfaceDeep: const Color(0xFF141414),
        copyButtonCopiedBg: const Color(0xFF0C1C14),
        copyButtonCopiedBorder: const Color(0xFF1A3226),
        buttonDisabled: const Color(0xFF3D3C44),
        buttonDanger: const Color(0x1AFF0000),
        skeletonBase: const Color(0xFF161616),
        skeletonHighlightA: const Color(0xFF000000),
        skeletonHighlightB: const Color(0xFF666666),
        tagGuardian: const Color(0xFF9747FF),
        tagEntrusted: const Color(0xFFFFD541),
        tagHighSecurity: const Color(0xFF4CEDE7),
      );

  @override
  AppColorsV2 copyWith({
    Color? background,
    Color? surface,
    Color? surfaceGlass,
    Color? surfaceCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? textError,
    Color? textLabel,
    Color? textLightGray,
    Color? accentOrange,
    Color? accentGreen,
    Color? checksum,
    Color? error,
    Color? danger,
    Color? success,
    Color? backgroundGlow,
    List<Color>? buttonPrimaryGradient,
    Color? separator,
    Color? txItemSeparator,
    Color? txItemIncomingHighlightBg,
    Color? txItemOutgoingHighlightBg,
    Color? txItemOutgoingHighlightBorder,
    Color? txItemIconDefault,
    Color? txItemIncomingHighlightBorder,
    Color? txItemBorderDefault,
    Color? border,
    Color? borderButton,
    Color? toasterBackground,
    Color? toasterBorder,
    Color? sheetBackground,
    Color? borderSubtle,
    Color? buttonDisabled,
    Color? buttonDanger,
    Color? borderDanger,
    Color? skeletonBase,
    Color? skeletonHighlightA,
    Color? skeletonHighlightB,
    Color? segmentedControlPill,
    Color? surfaceDeep,
    Color? copyButtonCopiedBg,
    Color? copyButtonCopiedBorder,
    Color? tagGuardian,
    Color? tagEntrusted,
    Color? tagHighSecurity,
  }) {
    return AppColorsV2(
      background: background ?? this.background,
      toasterBackground: toasterBackground ?? this.toasterBackground,
      toasterBorder: toasterBorder ?? this.toasterBorder,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderButton: borderButton ?? this.borderButton,
      surface: surface ?? this.surface,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      textError: textError ?? this.textError,
      textLabel: textLabel ?? this.textLabel,
      textLightGray: textLightGray ?? this.textLightGray,
      accentOrange: accentOrange ?? this.accentOrange,
      accentGreen: accentGreen ?? this.accentGreen,
      checksum: checksum ?? this.checksum,
      error: error ?? this.error,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      buttonPrimaryGradient: buttonPrimaryGradient ?? this.buttonPrimaryGradient,
      separator: separator ?? this.separator,
      txItemSeparator: txItemSeparator ?? this.txItemSeparator,
      txItemIncomingHighlightBg: txItemIncomingHighlightBg ?? this.txItemIncomingHighlightBg,
      txItemOutgoingHighlightBg: txItemOutgoingHighlightBg ?? this.txItemOutgoingHighlightBg,
      txItemOutgoingHighlightBorder: txItemOutgoingHighlightBorder ?? this.txItemOutgoingHighlightBorder,
      txItemIconDefault: txItemIconDefault ?? this.txItemIconDefault,
      txItemIncomingHighlightBorder: txItemIncomingHighlightBorder ?? this.txItemIncomingHighlightBorder,
      txItemBorderDefault: txItemBorderDefault ?? this.txItemBorderDefault,
      border: border ?? this.border,
      buttonDisabled: buttonDisabled ?? this.buttonDisabled,
      buttonDanger: buttonDanger ?? this.buttonDanger,
      borderDanger: borderDanger ?? this.borderDanger,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlightA: skeletonHighlightA ?? this.skeletonHighlightA,
      skeletonHighlightB: skeletonHighlightB ?? this.skeletonHighlightB,
      segmentedControlPill: segmentedControlPill ?? this.segmentedControlPill,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      copyButtonCopiedBg: copyButtonCopiedBg ?? this.copyButtonCopiedBg,
      copyButtonCopiedBorder: copyButtonCopiedBorder ?? this.copyButtonCopiedBorder,
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
      toasterBackground: Color.lerp(toasterBackground, other.toasterBackground, t) ?? toasterBackground,
      toasterBorder: Color.lerp(toasterBorder, other.toasterBorder, t) ?? toasterBorder,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t) ?? sheetBackground,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      borderButton: Color.lerp(borderButton, other.borderButton, t) ?? borderButton,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t) ?? surfaceGlass,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      textError: Color.lerp(textError, other.textError, t) ?? textError,
      textLabel: Color.lerp(textLabel, other.textLabel, t) ?? textLabel,
      textLightGray: Color.lerp(textLightGray, other.textLightGray, t) ?? textLightGray,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t) ?? accentOrange,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t) ?? accentGreen,
      checksum: Color.lerp(checksum, other.checksum, t) ?? checksum,
      error: Color.lerp(error, other.error, t) ?? error,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      success: Color.lerp(success, other.success, t) ?? success,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t) ?? backgroundGlow,
      buttonPrimaryGradient: other.buttonPrimaryGradient,
      separator: Color.lerp(separator, other.separator, t) ?? separator,
      txItemSeparator: Color.lerp(txItemSeparator, other.txItemSeparator, t) ?? txItemSeparator,
      txItemIncomingHighlightBg:
          Color.lerp(txItemIncomingHighlightBg, other.txItemIncomingHighlightBg, t) ?? txItemIncomingHighlightBg,
      txItemOutgoingHighlightBg:
          Color.lerp(txItemOutgoingHighlightBg, other.txItemOutgoingHighlightBg, t) ?? txItemOutgoingHighlightBg,
      txItemOutgoingHighlightBorder:
          Color.lerp(txItemOutgoingHighlightBorder, other.txItemOutgoingHighlightBorder, t) ??
          txItemOutgoingHighlightBorder,
      txItemIconDefault: Color.lerp(txItemIconDefault, other.txItemIconDefault, t) ?? txItemIconDefault,
      txItemIncomingHighlightBorder:
          Color.lerp(txItemIncomingHighlightBorder, other.txItemIncomingHighlightBorder, t) ??
          txItemIncomingHighlightBorder,
      txItemBorderDefault: Color.lerp(txItemBorderDefault, other.txItemBorderDefault, t) ?? txItemBorderDefault,
      border: Color.lerp(border, other.border, t) ?? border,
      buttonDisabled: Color.lerp(buttonDisabled, other.buttonDisabled, t) ?? buttonDisabled,
      buttonDanger: Color.lerp(buttonDanger, other.buttonDanger, t) ?? buttonDanger,
      borderDanger: Color.lerp(borderDanger, other.borderDanger, t) ?? borderDanger,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t) ?? skeletonBase,
      skeletonHighlightA: Color.lerp(skeletonHighlightA, other.skeletonHighlightA, t) ?? skeletonHighlightA,
      skeletonHighlightB: Color.lerp(skeletonHighlightB, other.skeletonHighlightB, t) ?? skeletonHighlightB,
      segmentedControlPill: Color.lerp(segmentedControlPill, other.segmentedControlPill, t) ?? segmentedControlPill,
      surfaceDeep: Color.lerp(surfaceDeep, other.surfaceDeep, t) ?? surfaceDeep,
      copyButtonCopiedBg: Color.lerp(copyButtonCopiedBg, other.copyButtonCopiedBg, t) ?? copyButtonCopiedBg,
      copyButtonCopiedBorder:
          Color.lerp(copyButtonCopiedBorder, other.copyButtonCopiedBorder, t) ?? copyButtonCopiedBorder,
      tagGuardian: Color.lerp(tagGuardian, other.tagGuardian, t) ?? tagGuardian,
      tagEntrusted: Color.lerp(tagEntrusted, other.tagEntrusted, t) ?? tagEntrusted,
      tagHighSecurity: Color.lerp(tagHighSecurity, other.tagHighSecurity, t) ?? tagHighSecurity,
    );
  }
}

extension AppColorsV2Extension on BuildContext {
  AppColorsV2 get colors => Theme.of(this).extension<AppColorsV2>()!;
}
