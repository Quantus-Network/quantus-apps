import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The cold wallet's tokens: the shared dark palette with the glacier accent
/// the Figma "Cold Wallet" page uses for every CTA and step label.
final AppColorsV3 coldColors = const AppColorsV3.dark().copyWith(accentFlare: const AppColorsV3.dark().semanticGlacier);

ThemeData coldTheme(BuildContext context) => AppTheme.darkTheme(context, colors: coldColors);

/// Cold wallet buttons are 56pt tall (Figma Button / Primary), 8pt taller than
/// the SDK default.
const EdgeInsets coldButtonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
