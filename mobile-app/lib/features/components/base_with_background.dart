import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';

class BaseWithBackground extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;

  const BaseWithBackground({super.key, required this.child, this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.54,
              child: Image.asset('assets/light_leak_effect_background.jpg', fit: BoxFit.cover),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
