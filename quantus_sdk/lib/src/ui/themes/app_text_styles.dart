import 'package:flutter/material.dart';

@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  static const fontFamily = 'Geist';
  static const fontFamilySecondary = 'Geist Mono';

  final TextStyle? lockTitle;
  final TextStyle? extraLargeTitle;
  final TextStyle? largeTitle;
  final TextStyle? mediumTitle;
  final TextStyle? smallTitle;
  final TextStyle? paragraph;
  final TextStyle? smallParagraph;
  final TextStyle? receiveLabel;
  final TextStyle? largeTag;
  final TextStyle? tag;
  final TextStyle? timer;
  final TextStyle? detail;
  final TextStyle? tiny;
  final TextStyle? totalMinedBlocks;
  final TextStyle? transactionDetailAmountPrimary;
  final TextStyle? transactionDetailAmountSymbol;
  final TextStyle? transactionDetailRowLabel;
  final TextStyle? transactionDetailRowValue;
  final TextStyle? sendSectionLabel;
  final TextStyle? conversionAmountPrimary;

  const AppTextTheme({
    this.lockTitle,
    this.extraLargeTitle,
    this.largeTitle,
    this.mediumTitle,
    this.smallTitle,
    this.paragraph,
    this.smallParagraph,
    this.receiveLabel,
    this.largeTag,
    this.tag,
    this.timer,
    this.detail,
    this.tiny,
    this.totalMinedBlocks,
    this.transactionDetailAmountPrimary,
    this.transactionDetailAmountSymbol,
    this.transactionDetailRowLabel,
    this.transactionDetailRowValue,
    this.sendSectionLabel,
    this.conversionAmountPrimary,
  });

  const AppTextTheme.defaultTheme()
    : this(
        lockTitle: const TextStyle(fontSize: 24, fontFamily: fontFamily),
        extraLargeTitle: const TextStyle(fontSize: 40, fontFamily: fontFamily, fontWeight: FontWeight.w600),
        largeTitle: const TextStyle(fontSize: 30, fontFamily: fontFamily, fontWeight: FontWeight.w300),
        mediumTitle: const TextStyle(fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.w500),
        smallTitle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        paragraph: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        smallParagraph: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        receiveLabel: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamilySecondary),
        largeTag: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        tag: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, fontFamily: fontFamily),
        timer: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        detail: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        tiny: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        totalMinedBlocks: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 56,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        transactionDetailAmountPrimary: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 64,
          fontWeight: FontWeight.w300,
          letterSpacing: -2.77,
          height: 1.0,
        ),
        transactionDetailAmountSymbol: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 24,
          fontWeight: FontWeight.w300,
        ),
        transactionDetailRowLabel: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.85,
        ),
        transactionDetailRowValue: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        sendSectionLabel: const TextStyle(
          fontSize: 20,
          height: 1.0,
          fontWeight: FontWeight.w400,
          fontFamily: fontFamily,
        ),
        conversionAmountPrimary: const TextStyle(
          fontSize: 40,
          fontFamily: fontFamilySecondary,
          fontWeight: FontWeight.w400,
        ),
      );

  const AppTextTheme.iPad()
    : this(
        lockTitle: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: fontFamily),
        extraLargeTitle: const TextStyle(fontSize: 52, fontFamily: fontFamily, fontWeight: FontWeight.w600),
        largeTitle: const TextStyle(fontSize: 36, fontFamily: fontFamily, fontWeight: FontWeight.w300),
        mediumTitle: const TextStyle(fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.w400),
        smallTitle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        paragraph: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        smallParagraph: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        receiveLabel: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, fontFamily: fontFamilySecondary),
        largeTag: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        tag: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, fontFamily: fontFamily),
        timer: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, fontFamily: fontFamily),
        detail: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        tiny: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, fontFamily: fontFamily),
        totalMinedBlocks: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 60,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        transactionDetailAmountPrimary: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 80,
          fontWeight: FontWeight.w300,
          letterSpacing: -2.77,
          height: 1.0,
        ),
        transactionDetailAmountSymbol: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 30,
          fontWeight: FontWeight.w300,
        ),
        transactionDetailRowLabel: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.85,
        ),
        transactionDetailRowValue: const TextStyle(
          fontFamily: fontFamilySecondary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        sendSectionLabel: const TextStyle(
          fontSize: 24,
          height: 1.0,
          fontWeight: FontWeight.w400,
          fontFamily: fontFamily,
        ),
        conversionAmountPrimary: const TextStyle(
          fontSize: 52,
          fontFamily: fontFamilySecondary,
          fontWeight: FontWeight.w400,
        ),
      );

  @override
  AppTextTheme copyWith({
    TextStyle? lockTitle,
    TextStyle? extraLargeTitle,
    TextStyle? largeTitle,
    TextStyle? mediumTitle,
    TextStyle? smallTitle,
    TextStyle? paragraph,
    TextStyle? smallParagraph,
    TextStyle? receiveLabel,
    TextStyle? largeTag,
    TextStyle? tag,
    TextStyle? timer,
    TextStyle? detail,
    TextStyle? tiny,
    TextStyle? totalMinedBlocks,
    TextStyle? transactionDetailAmountPrimary,
    TextStyle? transactionDetailAmountSymbol,
    TextStyle? transactionDetailRowLabel,
    TextStyle? transactionDetailRowValue,
    TextStyle? sendSectionLabel,
    TextStyle? conversionAmountPrimary,
  }) {
    return AppTextTheme(
      lockTitle: lockTitle ?? this.lockTitle,
      extraLargeTitle: extraLargeTitle ?? this.extraLargeTitle,
      largeTitle: largeTitle ?? this.largeTitle,
      mediumTitle: mediumTitle ?? this.mediumTitle,
      smallTitle: smallTitle ?? this.smallTitle,
      paragraph: paragraph ?? this.paragraph,
      smallParagraph: smallParagraph ?? this.smallParagraph,
      receiveLabel: receiveLabel ?? this.receiveLabel,
      largeTag: largeTag ?? this.largeTag,
      tag: tag ?? this.tag,
      timer: timer ?? this.timer,
      detail: detail ?? this.detail,
      tiny: tiny ?? this.tiny,
      totalMinedBlocks: totalMinedBlocks ?? this.totalMinedBlocks,
      transactionDetailAmountPrimary: transactionDetailAmountPrimary ?? this.transactionDetailAmountPrimary,
      transactionDetailAmountSymbol: transactionDetailAmountSymbol ?? this.transactionDetailAmountSymbol,
      transactionDetailRowLabel: transactionDetailRowLabel ?? this.transactionDetailRowLabel,
      transactionDetailRowValue: transactionDetailRowValue ?? this.transactionDetailRowValue,
      sendSectionLabel: sendSectionLabel ?? this.sendSectionLabel,
      conversionAmountPrimary: conversionAmountPrimary ?? this.conversionAmountPrimary,
    );
  }

  @override
  AppTextTheme lerp(AppTextTheme? other, double t) {
    if (other is! AppTextTheme) return this;
    return AppTextTheme(
      lockTitle: TextStyle.lerp(lockTitle, other.lockTitle, t),
      extraLargeTitle: TextStyle.lerp(extraLargeTitle, other.extraLargeTitle, t),
      largeTitle: TextStyle.lerp(largeTitle, other.largeTitle, t),
      mediumTitle: TextStyle.lerp(mediumTitle, other.mediumTitle, t),
      smallTitle: TextStyle.lerp(smallTitle, other.smallTitle, t),
      paragraph: TextStyle.lerp(paragraph, other.paragraph, t),
      smallParagraph: TextStyle.lerp(smallParagraph, other.smallParagraph, t),
      receiveLabel: TextStyle.lerp(receiveLabel, other.receiveLabel, t),
      largeTag: TextStyle.lerp(largeTag, other.largeTag, t),
      tag: TextStyle.lerp(tag, other.tag, t),
      timer: TextStyle.lerp(timer, other.timer, t),
      detail: TextStyle.lerp(detail, other.detail, t),
      tiny: TextStyle.lerp(tiny, other.tiny, t),
      totalMinedBlocks: TextStyle.lerp(totalMinedBlocks, other.totalMinedBlocks, t),
      transactionDetailAmountPrimary: TextStyle.lerp(
        transactionDetailAmountPrimary,
        other.transactionDetailAmountPrimary,
        t,
      ),
      transactionDetailAmountSymbol: TextStyle.lerp(
        transactionDetailAmountSymbol,
        other.transactionDetailAmountSymbol,
        t,
      ),
      transactionDetailRowLabel: TextStyle.lerp(transactionDetailRowLabel, other.transactionDetailRowLabel, t),
      transactionDetailRowValue: TextStyle.lerp(transactionDetailRowValue, other.transactionDetailRowValue, t),
      sendSectionLabel: TextStyle.lerp(sendSectionLabel, other.sendSectionLabel, t),
      conversionAmountPrimary: TextStyle.lerp(conversionAmountPrimary, other.conversionAmountPrimary, t),
    );
  }
}

extension AppTextThemeExtension on BuildContext {
  AppTextTheme get themeText => Theme.of(this).extension<AppTextTheme>()!;
}

/// Quantus App v3 text styles, mapped 1:1 from Figma SYSTEM / Text Styles.
///
/// Do not add styles that are not in the Figma table. Apply color at the call
/// site via [TextStyle.copyWith] using [AppColorsV3] tokens.
@immutable
class AppTextThemeV3 extends ThemeExtension<AppTextThemeV3> {
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

  /// Hidden balances.
  final TextStyle dataMasked;

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
    required this.dataMasked,
    required this.labelData,
    required this.labelMonogram,
  });

  /// Typography from Figma SYSTEM / Text Styles.
  const AppTextThemeV3.standard()
    : this(
        displayCharge: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 80,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        displayBalance: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        titleSuccess: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        titleHero: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        amountHero: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        titleScreen: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        amountInline: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        amountRow: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.0,
          fontFeatures: [_tabularFigures],
        ),
        headingRow: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        bodyLarge: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        bodyEmphasis: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        body: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        caption: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        labelChip: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        dataAddress: const TextStyle(
          fontFamily: AppTextTheme.fontFamilySecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        dataAddressLarge: const TextStyle(
          fontFamily: AppTextTheme.fontFamilySecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        dataMasked: const TextStyle(
          fontFamily: AppTextTheme.fontFamilySecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.0,
        ),
        labelData: const TextStyle(
          fontFamily: AppTextTheme.fontFamilySecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
        labelMonogram: const TextStyle(
          fontFamily: AppTextTheme.fontFamilySecondary,
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
    TextStyle? dataMasked,
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
      dataMasked: dataMasked ?? this.dataMasked,
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
      dataMasked: TextStyle.lerp(dataMasked, other.dataMasked, t) ?? dataMasked,
      labelData: TextStyle.lerp(labelData, other.labelData, t) ?? labelData,
      labelMonogram: TextStyle.lerp(labelMonogram, other.labelMonogram, t) ?? labelMonogram,
    );
  }
}

extension AppTextThemeV3Extension on BuildContext {
  AppTextThemeV3 get themeTextV3 => Theme.of(this).extension<AppTextThemeV3>()!;
}
