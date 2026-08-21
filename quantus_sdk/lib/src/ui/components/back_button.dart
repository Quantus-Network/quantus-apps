import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AppBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final double containerSize = 28;
    final double iconSize = 24;

    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: GlassButtonBase(
        buttonHeight: containerSize,
        buttonWidth: containerSize,
        borderRadius: BorderRadius.circular(containerSize / 2),
        padding: const EdgeInsets.all(2),
        child: QuantusIcon(QuantusIcons.chevronLeft, size: iconSize, color: context.colorsV3.textContent),
      ),
    );
  }
}
