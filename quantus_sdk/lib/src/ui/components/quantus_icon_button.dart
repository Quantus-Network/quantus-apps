import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

enum IconButtonShape { rounded, circular }

enum IconButtonStyle { glass, flat, ghost }

enum IconButtonSize { small, medium, large }

class QuantusIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final IconButtonSize size;
  final IconButtonShape shape;
  final IconButtonStyle style;
  final bool isDisabled;
  final bool isLoading;
  final bool isActive;
  final double? radius;

  const QuantusIconButton.rounded({
    super.key,
    required this.icon,
    this.size = IconButtonSize.medium,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.radius,
    this.style = IconButtonStyle.flat,
  }) : shape = IconButtonShape.rounded;

  const QuantusIconButton.circular({
    super.key,
    required this.icon,
    this.size = IconButtonSize.medium,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.radius,
    this.style = IconButtonStyle.flat,
  }) : shape = IconButtonShape.circular;

  const QuantusIconButton.ghost({
    super.key,
    required this.icon,
    this.size = IconButtonSize.medium,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.radius,
    this.shape = IconButtonShape.rounded,
  }) : style = IconButtonStyle.ghost;

  double get buttonSize {
    switch (size) {
      case IconButtonSize.small:
        return 28;
      case IconButtonSize.medium:
        return 36;
      case IconButtonSize.large:
        return 44;
    }
  }

  double get iconSize {
    switch (size) {
      case IconButtonSize.small:
        return 16;
      case IconButtonSize.medium:
        return 18;
      case IconButtonSize.large:
        return 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final colors = context.colorsV3;
    final radiusTokens = context.radiusV3;
    final double defaultRadius = size == IconButtonSize.small ? radiusTokens.sm : radiusTokens.md;
    final double cornerRadius = radius ?? defaultRadius;
    final Color iconColor = disabled
        ? colors.textMuted2
        : isActive
        ? colors.accentFlare
        : colors.textContent;

    final BorderRadius borderRadius;
    switch (shape) {
      case IconButtonShape.rounded:
        borderRadius = BorderRadius.circular(cornerRadius);
        break;
      case IconButtonShape.circular:
        borderRadius = BorderRadius.circular(buttonSize / 2);
        break;
    }

    Widget content = Center(
      child: isLoading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(color: iconColor, strokeWidth: 1.5),
            )
          : Icon(icon, color: iconColor, size: iconSize),
    );

    switch (style) {
      case IconButtonStyle.glass:
        content = _buildGlassStyle(content, buttonSize: buttonSize, borderRadius: borderRadius);
        break;
      case IconButtonStyle.flat:
        content = _buildFlatStyle(
          content,
          buttonSize: buttonSize,
          borderRadius: borderRadius,
          colors: colors,
          disabled: disabled,
        );
        break;
      case IconButtonStyle.ghost:
        content = _buildGhostStyle(content, buttonSize: buttonSize, borderRadius: borderRadius);
        break;
    }

    return InkWell(onTap: disabled ? null : onTap, borderRadius: borderRadius, child: content);
  }

  Widget _buildFlatStyle(
    Widget child, {
    required double buttonSize,
    required BorderRadius borderRadius,
    required AppColorsV3 colors,
    required bool disabled,
  }) {
    final Border? border = disabled
        ? null
        : Border.all(color: isActive ? colors.accentFlare.useOpacity(0.2) : colors.borderHairline, width: 1);

    return Container(
      decoration: BoxDecoration(
        color: disabled ? colors.bgSurface2 : colors.bgSurface,
        border: border,
        borderRadius: borderRadius,
      ),
      child: SizedBox(width: buttonSize, height: buttonSize, child: child),
    );
  }

  Widget _buildGlassStyle(Widget child, {required double buttonSize, required BorderRadius borderRadius}) {
    return GlassButtonBase(buttonHeight: buttonSize, buttonWidth: buttonSize, borderRadius: borderRadius, child: child);
  }

  Widget _buildGhostStyle(Widget child, {required double buttonSize, required BorderRadius borderRadius}) {
    return SizedBox(width: buttonSize, height: buttonSize, child: child);
  }
}
