import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The cold wallet's tokens: the shared dark palette with the glacier accent
/// the Figma "Cold Wallet" page uses for every CTA and step label.
final AppColorsV3 coldColors = const AppColorsV3.dark().copyWith(accentFlare: const AppColorsV3.dark().semanticGlacier);

/// The shared dark theme with every accent use switched to [coldColors].
ThemeData coldTheme(BuildContext context) {
  final base = AppTheme.darkTheme(context);
  final accent = coldColors.accentFlare;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.useOpacity(0.2),
      selectionHandleColor: accent,
    ),
    extensions: [coldColors, const AppTextThemeV3.standard(), const AppRadiusV3.standard()],
  );
}

/// Cold wallet buttons are 56pt tall (Figma Button / Primary), 8pt taller than
/// the SDK default.
const EdgeInsets coldButtonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
