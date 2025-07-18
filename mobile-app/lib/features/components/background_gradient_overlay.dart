import 'package:flutter/material.dart';

class BackgroundGradientOverlay extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry? borderRadius;

  const BackgroundGradientOverlay({
    super.key,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment(0.37, -0.01),
          end: Alignment(0.37, 1.00),
          colors: [Colors.black, Color(0xFF312E6E)],
        ),
      ),
      child: child,
    );
  }
}
