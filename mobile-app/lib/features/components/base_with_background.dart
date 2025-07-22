import 'package:flutter/material.dart';

class BaseWithBackground extends StatelessWidget {
  final Widget child;

  const BaseWithBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.54,
              child: Image.asset(
                'assets/light_leak_effect_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
