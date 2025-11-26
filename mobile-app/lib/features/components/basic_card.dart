import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';

class BasicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const BasicCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? const EdgeInsets.symmetric(vertical: 5, horizontal: 14);

    return Container(
      width: double.infinity,
      padding: effectivePadding,
      decoration: BoxDecoration(color: context.themeColors.buttonGlass),
      child: child,
    );
  }
}
