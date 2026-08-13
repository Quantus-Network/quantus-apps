import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AppTheme {
  static ThemeData darkTheme(BuildContext context) {
    final isTablet = context.isTablet;
    final colors = const AppColorsV2.dark();
    final text = isTablet ? const AppTextTheme.iPad() : const AppTextTheme.defaultTheme();
    const radius = AppRadiusV3.standard();

    return ThemeData(
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface,
      colorScheme: ColorScheme.dark(surface: colors.surface, error: colors.error),
      appBarTheme: AppBarTheme(backgroundColor: colors.surface, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: radius.mdBorder),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius.mdBorder)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: colors.textPrimary)),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentOrange,
        selectionColor: colors.accentOrange.useOpacity(0.2),
        selectionHandleColor: colors.accentOrange,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: text.smallParagraph?.copyWith(color: colors.textLabel, fontFamily: AppTextTheme.fontFamilySecondary),
        contentPadding: EdgeInsets.zero,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
      ),
      extensions: [colors, const AppColorsV3.dark(), text, const AppTextThemeV3.standard(), radius],
    );
  }
}
