import 'package:flutter/material.dart';

class BaseWithBackground extends StatelessWidget {
  final Widget child;
  final AppBar? appBar;

  const BaseWithBackground({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
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
