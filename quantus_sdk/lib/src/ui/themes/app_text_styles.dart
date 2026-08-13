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
