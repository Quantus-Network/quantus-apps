import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/liquid_glass_base.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

enum IconButtonShape { rounded, circular }

enum IconButtonSize { small, medium }

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconButtonSize size;
  final IconButtonShape shape;
  final bool isDisabled;

  const GlassIconButton.rounded({
    super.key,
    required this.icon,
    this.size = IconButtonSize.medium,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  }) : shape = IconButtonShape.rounded;

  const GlassIconButton.circular({
    super.key,
    required this.icon,
    this.size = IconButtonSize.medium,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
  }) : shape = IconButtonShape.circular;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final visibility = disabled ? 0.92 : 1.0;
    final glassColor = context.colors.surfaceGlass;

    final double buttonSize = size == IconButtonSize.small ? 24 : 40;
    final double iconSize = size == IconButtonSize.small ? 12 : 20;
    final double radius = size == IconButtonSize.small ? 6 : 14;

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
      case IconButtonShape.rounded:
        buttonWidget = LiquidGlassBase.rounded(
          visibility: visibility,
          glassColor: glassColor,
          radius: radius,
          child: SizedBox(width: buttonSize, height: buttonSize, child: buttonContent),
        );
        break;

      case IconButtonShape.circular:
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
