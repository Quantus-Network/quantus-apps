import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class GradientText extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final List<double>? stops;
  final TextStyle? style;

  const GradientText(this.text, {super.key, required this.colors, this.stops, required this.style});

  factory GradientText.highSecurity(String text, BuildContext context) {
    return GradientText(
      'THEFT DETERRENCE',
      colors: context.themeColors.aquaBlue,
      stops: const [0.45, 1], // This means the gradient starts at 45% and ends at 100%
      style: context.themeText.largeTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        stops: stops,
        begin: const Alignment(0.00, -1.00),
        end: const Alignment(0, 1),
      ).createShader(bounds),
      child: Text(text, style: style?.copyWith(color: Colors.white)),
    );
  }
}
