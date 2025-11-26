import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AppTheme {
  static ThemeData lightTheme(BuildContext context) {
    final appColors = const AppColorsTheme.light();

    return ThemeData(
      primaryColor: appColors.primary,
      scaffoldBackgroundColor: appColors.background,
      cardColor: appColors.surface,
      colorScheme: ColorScheme.dark(
        primary: appColors.primary,
        secondary: appColors.secondary,
        surface: appColors.surface,
        error: appColors.error,
      ),
      appBarTheme: AppBarTheme(backgroundColor: appColors.surface, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors.primary,
          foregroundColor: appColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appColors.secondary,
          side: BorderSide(color: appColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: appColors.textPrimary)),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: appColors.surface,
      ),
    );
  }

  static ThemeData darkTheme(BuildContext context) {
    final isTablet = context.isTablet;
    final appColors = const AppColorsTheme.dark();

    return ThemeData(
      primaryColor: appColors.primary,
      scaffoldBackgroundColor: appColors.background,
      cardColor: appColors.surface,
      colorScheme: ColorScheme.dark(
        primary: appColors.primary,
        secondary: appColors.secondary,
        surface: appColors.surface,
        error: appColors.error,
      ),
      appBarTheme: AppBarTheme(backgroundColor: appColors.surface, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appColors.secondary,
          side: BorderSide(color: appColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: appColors.textPrimary)),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: appColors.surface,
      ),
      extensions: [
        isTablet ? const AppTextTheme.iPad() : const AppTextTheme.defaultTheme(),
        isTablet ? const AppSizeTheme.iPad() : const AppSizeTheme.defaultTheme(),
        appColors,
      ],
    );
  }
}
