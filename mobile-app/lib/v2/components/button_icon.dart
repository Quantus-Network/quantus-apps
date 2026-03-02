import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/liquid_glass_base.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

enum ButtonIconShape { rounded, circular }

enum ButtonIconSize { small, medium }

class ButtonIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final ButtonIconSize size;
  final ButtonIconShape shape;
  final bool isDisabled;

  const ButtonIcon.rounded({
    super.key,
    required this.icon,
    this.size = ButtonIconSize.medium,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  }) : shape = ButtonIconShape.rounded;

  const ButtonIcon.circular({
    super.key,
    required this.icon,
    this.size = ButtonIconSize.medium,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  }) : shape = ButtonIconShape.circular;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final visibility = disabled ? 0.92 : 1.0;
    final glassColor = context.colors.surfaceGlass;

    final double buttonSize = size == ButtonIconSize.small ? 24 : 40;
    final double iconSize = size == ButtonIconSize.small ? 12 : 20;
    final double radius = size == ButtonIconSize.small ? 6 : 14;

    final buttonContent = Center(
      child: isLoading
          ? SizedBox(
              width: buttonSize + 6,
              height: buttonSize + 6,
              child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.0),
            )
          : SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: Icon(icon, color: context.colors.textPrimary, size: iconSize),
            ),
    );

    Widget buttonWidget;

    switch (shape) {
      case ButtonIconShape.rounded:
        buttonWidget = LiquidGlassBase.rounded(
          visibility: visibility,
          glassColor: glassColor,
          radius: radius,
          child: SizedBox(width: buttonSize, height: buttonSize, child: buttonContent),
        );
        break;

      case ButtonIconShape.circular:
        buttonWidget = LiquidGlassBase.circular(
          visibility: visibility,
          glassColor: glassColor,
          child: SizedBox(width: buttonSize, height: buttonSize, child: buttonContent),
        );
        break;
    }

    return InkWell(onTap: disabled ? null : onTap, child: buttonWidget);
  }
}
