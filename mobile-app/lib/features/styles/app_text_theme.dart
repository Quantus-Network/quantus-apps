import 'package:flutter/material.dart';

/// App text themes
///
/// Use with the extension!, like this:
///             Text(
///               'This is a small paragraph text.',
///               style: context.smallParagraph, // Uses extension getter
///             ),

// AppTextTheme class (as provided previously)
@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  final TextStyle? smallTitle;
  final TextStyle? paragraph;
  final TextStyle? smallParagraph;
  final TextStyle? largeTag;
  final TextStyle? detail;
  final TextStyle? tiny;

  const AppTextTheme({
    this.smallTitle,
    this.paragraph,
    this.smallParagraph,
    this.largeTag,
    this.detail,
    this.tiny,
  });

  const AppTextTheme.fallback()
    : this(
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
        detail: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tiny: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
      );

  const AppTextTheme.iPad()
    : this(
        smallTitle: const TextStyle(
          fontSize: 22,
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
          fontSize: 20,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        detail: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        tiny: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Fira Code',
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
      );

  @override
  AppTextTheme copyWith({
    TextStyle? smallTitle,
    TextStyle? paragraph,
    TextStyle? smallParagraph,
    TextStyle? largeTag,
    TextStyle? detail,
    TextStyle? tiny,
  }) {
    return AppTextTheme(
      smallTitle: smallTitle ?? this.smallTitle,
      paragraph: paragraph ?? this.paragraph,
      smallParagraph: smallParagraph ?? this.smallParagraph,
      largeTag: largeTag ?? this.largeTag,
      detail: detail ?? this.detail,
      tiny: tiny ?? this.tiny,
    );
  }

  @override
  AppTextTheme lerp(AppTextTheme? other, double t) {
    if (other is! AppTextTheme) return this;
    return AppTextTheme(
      smallTitle: TextStyle.lerp(smallTitle, other.smallTitle, t),
      paragraph: TextStyle.lerp(paragraph, other.paragraph, t),
      smallParagraph: TextStyle.lerp(smallParagraph, other.smallParagraph, t),
      largeTag: TextStyle.lerp(largeTag, other.largeTag, t),
      detail: TextStyle.lerp(detail, other.detail, t),
      tiny: TextStyle.lerp(tiny, other.tiny, t),
    );
  }
}

// Extension on BuildContext to access AppTextTheme styles directly
extension AppTextThemeExtension on BuildContext {
  TextStyle? get smallTitle =>
      Theme.of(this).extension<AppTextTheme>()?.smallTitle;
  TextStyle? get paragraph =>
      Theme.of(this).extension<AppTextTheme>()?.paragraph;
  TextStyle? get smallParagraph =>
      Theme.of(this).extension<AppTextTheme>()?.smallParagraph;
  TextStyle? get largeTag => Theme.of(this).extension<AppTextTheme>()?.largeTag;
  TextStyle? get detail => Theme.of(this).extension<AppTextTheme>()?.detail;
  TextStyle? get tiny => Theme.of(this).extension<AppTextTheme>()?.tiny;
}
