import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final TextStyle? style;

  const GradientText(this.text, {super.key, required this.colors, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: const Alignment(0.00, -1.00),
        end: const Alignment(0, 1),
      ).createShader(bounds),
      child: Text(text, style: style?.copyWith(color: Colors.white)),
    );
  }
}
