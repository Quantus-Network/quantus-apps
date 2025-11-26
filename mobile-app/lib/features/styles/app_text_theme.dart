import 'package:flutter/material.dart';

@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  final TextStyle? lockTitle;
  final TextStyle? extraLargeTitle;
  final TextStyle? largeTitle;
  final TextStyle? mediumTitle;
  final TextStyle? smallTitle;
  final TextStyle? paragraph;
  final TextStyle? smallParagraph;
  final TextStyle? largeTag;
  final TextStyle? tag;
  final TextStyle? timer;
  final TextStyle? detail;
  final TextStyle? tiny;

  const AppTextTheme({
    this.lockTitle,
    this.extraLargeTitle,
    this.largeTitle,
    this.mediumTitle,
    this.smallTitle,
    this.paragraph,
    this.smallParagraph,
    this.largeTag,
    this.tag,
    this.timer,
    this.detail,
    this.tiny,
  });

  const AppTextTheme.defaultTheme()
    : this(
        lockTitle: const TextStyle(fontSize: 24, fontFamily: 'Fira Code'),
        extraLargeTitle: const TextStyle(fontSize: 40, fontFamily: 'Fira Code', fontWeight: FontWeight.w600),
        largeTitle: const TextStyle(fontSize: 30, fontFamily: 'Fira Code', fontWeight: FontWeight.w300),
        mediumTitle: const TextStyle(fontSize: 24, fontFamily: 'Fira Code', fontWeight: FontWeight.w500),
        smallTitle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        paragraph: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        smallParagraph: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        largeTag: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tag: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300, fontFamily: 'Fira Code'),
        timer: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, fontFamily: 'Fira Code'),
        detail: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tiny: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
      );

  const AppTextTheme.iPad()
    : this(
        lockTitle: const TextStyle(color: Colors.white, fontSize: 28, fontFamily: 'Fira Code'),
        extraLargeTitle: const TextStyle(fontSize: 52, fontFamily: 'Fira Code', fontWeight: FontWeight.w600),
        largeTitle: const TextStyle(fontSize: 36, fontFamily: 'Fira Code', fontWeight: FontWeight.w300),
        mediumTitle: const TextStyle(fontSize: 28, fontFamily: 'Fira Code', fontWeight: FontWeight.w400),
        smallTitle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        paragraph: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        smallParagraph: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        largeTag: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tag: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, fontFamily: 'Fira Code'),
        timer: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, fontFamily: 'Fira Code'),
        detail: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tiny: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
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
    TextStyle? largeTag,
    TextStyle? tag,
    TextStyle? timer,
    TextStyle? detail,
    TextStyle? tiny,
  }) {
    return AppTextTheme(
      lockTitle: lockTitle ?? this.lockTitle,
      extraLargeTitle: extraLargeTitle ?? this.extraLargeTitle,
      largeTitle: largeTitle ?? this.largeTitle,
      mediumTitle: mediumTitle ?? this.mediumTitle,
      smallTitle: smallTitle ?? this.smallTitle,
      paragraph: paragraph ?? this.paragraph,
      smallParagraph: smallParagraph ?? this.smallParagraph,
      largeTag: largeTag ?? this.largeTag,
      tag: tag ?? this.tag,
      timer: timer ?? this.timer,
      detail: detail ?? this.detail,
      tiny: tiny ?? this.tiny,
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
      largeTag: TextStyle.lerp(largeTag, other.largeTag, t),
      tag: TextStyle.lerp(tag, other.tag, t),
      timer: TextStyle.lerp(timer, other.timer, t),
      detail: TextStyle.lerp(detail, other.detail, t),
      tiny: TextStyle.lerp(tiny, other.tiny, t),
    );
  }
}

// Extension on BuildContext to access AppTextTheme styles directly
extension AppTextThemeExtension on BuildContext {
  AppTextTheme get themeText => Theme.of(this).extension<AppTextTheme>()!;
}
