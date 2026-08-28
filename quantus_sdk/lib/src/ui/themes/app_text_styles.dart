import 'package:flutter/material.dart';

/// Quantus App v3 text styles, mapped 1:1 from Figma SYSTEM / Text Styles.
///
/// Do not add styles that are not in the Figma table. Apply color at the call
/// site via [TextStyle.copyWith] using [AppColorsV3] tokens.
@immutable
class AppTextThemeV3 extends ThemeExtension<AppTextThemeV3> {
  static const fontFamily = 'Geist';
  static const fontFamilySecondary = 'Geist Mono';

  /// POS charge display. Tabular figures.
  final TextStyle displayCharge;

  /// Home balance. Tabular figures.
  final TextStyle displayBalance;

  /// Terminal state titles.
  final TextStyle titleSuccess;

  /// Onboarding and hero headers.
  final TextStyle titleHero;

  /// Review-scale amounts. Tabular.
  final TextStyle amountHero;

  /// Nav titles. 18px merged up here.
  final TextStyle titleScreen;

  /// Inline numerics. Tabular.
  final TextStyle amountInline;

  /// Row amounts. Tabular.
  final TextStyle amountRow;

  /// Row and list headings.
  final TextStyle headingRow;

  /// Row titles, action labels.
  final TextStyle bodyLarge;

  /// Emphasized body.
  final TextStyle bodyEmphasis;

  /// Default body text.
  final TextStyle body;

  /// Supporting text.
  final TextStyle caption;

  /// Badges and chips.
  final TextStyle labelChip;

  /// Truncated addresses. Mono, always.
  final TextStyle dataAddress;

  /// Full addresses on verification surfaces.
  final TextStyle dataAddressLarge;

  /// Dossier data labels.
  final TextStyle labelData;

  /// Account initials.
  final TextStyle labelMonogram;

  const AppTextThemeV3({
    required this.displayCharge,
    required this.displayBalance,
    required this.titleSuccess,
    required this.titleHero,
    required this.amountHero,
    required this.titleScreen,
    required this.amountInline,
    required this.amountRow,
    required this.headingRow,
    required this.bodyLarge,
    required this.bodyEmphasis,
    required this.body,
    required this.caption,
    required this.labelChip,
    required this.dataAddress,
    required this.dataAddressLarge,
    required this.labelData,
    required this.labelMonogram,
  });

  /// Typography from Figma SYSTEM / Text Styles.
  const AppTextThemeV3.standard()
    : this(
        displayCharge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 80,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        displayBalance: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        titleSuccess: const TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w400, height: 1.0),
        titleHero: const TextStyle(fontFamily: fontFamily, fontSize: 28, fontWeight: FontWeight.w500, height: 1.0),
        amountHero: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        titleScreen: const TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w500, height: 1.0),
        amountInline: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        amountRow: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        headingRow: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w500, height: 1.0),
        bodyLarge: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, height: 1.25),
        bodyEmphasis: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500, height: 1.25),
        body: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, height: 1.25),
        caption: const TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, height: 1.25),
        labelChip: const TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, height: 1.0),
        dataAddress: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        dataAddressLarge: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
        labelData: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        labelMonogram: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      );

  static const _tabularFigures = FontFeature.tabularFigures();

  @override
  AppTextThemeV3 copyWith({
    TextStyle? displayCharge,
    TextStyle? displayBalance,
    TextStyle? titleSuccess,
    TextStyle? titleHero,
    TextStyle? amountHero,
    TextStyle? titleScreen,
    TextStyle? amountInline,
    TextStyle? amountRow,
    TextStyle? headingRow,
    TextStyle? bodyLarge,
    TextStyle? bodyEmphasis,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? labelChip,
    TextStyle? dataAddress,
    TextStyle? dataAddressLarge,
    TextStyle? labelData,
    TextStyle? labelMonogram,
  }) {
    return AppTextThemeV3(
      displayCharge: displayCharge ?? this.displayCharge,
      displayBalance: displayBalance ?? this.displayBalance,
      titleSuccess: titleSuccess ?? this.titleSuccess,
      titleHero: titleHero ?? this.titleHero,
      amountHero: amountHero ?? this.amountHero,
      titleScreen: titleScreen ?? this.titleScreen,
      amountInline: amountInline ?? this.amountInline,
      amountRow: amountRow ?? this.amountRow,
      headingRow: headingRow ?? this.headingRow,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyEmphasis: bodyEmphasis ?? this.bodyEmphasis,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      labelChip: labelChip ?? this.labelChip,
      dataAddress: dataAddress ?? this.dataAddress,
      dataAddressLarge: dataAddressLarge ?? this.dataAddressLarge,
      labelData: labelData ?? this.labelData,
      labelMonogram: labelMonogram ?? this.labelMonogram,
    );
  }

  @override
  AppTextThemeV3 lerp(AppTextThemeV3? other, double t) {
    if (other is! AppTextThemeV3) return this;
    return AppTextThemeV3(
      displayCharge: TextStyle.lerp(displayCharge, other.displayCharge, t) ?? displayCharge,
      displayBalance: TextStyle.lerp(displayBalance, other.displayBalance, t) ?? displayBalance,
      titleSuccess: TextStyle.lerp(titleSuccess, other.titleSuccess, t) ?? titleSuccess,
      titleHero: TextStyle.lerp(titleHero, other.titleHero, t) ?? titleHero,
      amountHero: TextStyle.lerp(amountHero, other.amountHero, t) ?? amountHero,
      titleScreen: TextStyle.lerp(titleScreen, other.titleScreen, t) ?? titleScreen,
      amountInline: TextStyle.lerp(amountInline, other.amountInline, t) ?? amountInline,
      amountRow: TextStyle.lerp(amountRow, other.amountRow, t) ?? amountRow,
      headingRow: TextStyle.lerp(headingRow, other.headingRow, t) ?? headingRow,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t) ?? bodyLarge,
      bodyEmphasis: TextStyle.lerp(bodyEmphasis, other.bodyEmphasis, t) ?? bodyEmphasis,
      body: TextStyle.lerp(body, other.body, t) ?? body,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
      labelChip: TextStyle.lerp(labelChip, other.labelChip, t) ?? labelChip,
      dataAddress: TextStyle.lerp(dataAddress, other.dataAddress, t) ?? dataAddress,
      dataAddressLarge: TextStyle.lerp(dataAddressLarge, other.dataAddressLarge, t) ?? dataAddressLarge,
      labelData: TextStyle.lerp(labelData, other.labelData, t) ?? labelData,
      labelMonogram: TextStyle.lerp(labelMonogram, other.labelMonogram, t) ?? labelMonogram,
    );
  }
}

extension AppTextThemeV3Extension on BuildContext {
  AppTextThemeV3 get themeTextV3 => Theme.of(this).extension<AppTextThemeV3>()!;
}
