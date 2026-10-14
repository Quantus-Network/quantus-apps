import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AppTheme {
  static ThemeData darkTheme(BuildContext context) {
    const colors = AppColorsV3.dark();
    const text = AppTextThemeV3.standard();
    const radius = AppRadiusV3.standard();

    return ThemeData(
      fontFamily: AppTextThemeV3.fontFamily,
      scaffoldBackgroundColor: colors.bgVoid,
      cardColor: colors.bgSurface,
      colorScheme: ColorScheme.dark(
        primary: colors.accentFlare,
        onPrimary: colors.textVoid,
        surface: colors.bgSurface,
        onSurface: colors.textContent,
        error: colors.semanticEmber,
        onError: colors.textContent,
      ),
      appBarTheme: AppBarTheme(backgroundColor: colors.bgSurface, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius.mdBorder)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius.mdBorder)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: colors.textContent)),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentFlare,
        selectionColor: colors.accentFlare.useOpacity(0.2),
        selectionHandleColor: colors.accentFlare,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: text.body.copyWith(color: colors.textMuted),
        contentPadding: EdgeInsets.zero,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
      ),
      extensions: const [colors, text, radius],
    );
  }
}
