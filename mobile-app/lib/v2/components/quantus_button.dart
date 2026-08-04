import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum ButtonVariant { transparent, primary, secondary, danger, success, outline, glass, underline }

enum IconPlacement { leading, trailing, top }

class QuantusButton extends StatelessWidget {
  final Widget? child;
  final String? _label;
  final Widget? _icon;
  final IconPlacement _iconPlacement;
  final TextStyle? _textStyle;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? width;
  final EdgeInsets padding;
  final ButtonVariant variant;
  final bool isDisabled;
  final double borderRadius;
  final bool centered;

  static const double defaultBorderRadius = 14.0;
  static const double buttonFontSize = 16.0;

  const QuantusButton({
    super.key,
    required Widget this.child,
    this.onTap,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.variant = ButtonVariant.primary,
    this.isDisabled = false,
    this.borderRadius = defaultBorderRadius,
    this.centered = true,
  }) : _label = null,
       _icon = null,
       _iconPlacement = IconPlacement.trailing,
       _textStyle = null;

  // this is a simple button with a label and an icon
  const QuantusButton.simple({
    super.key,
    required String label,
    Widget? icon,
    IconPlacement iconPlacement = IconPlacement.trailing,
    this.onTap,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
    TextStyle? textStyle,
    this.variant = ButtonVariant.primary,
    this.isDisabled = false,
    this.borderRadius = defaultBorderRadius,
    this.centered = true,
  }) : _label = label,
       _icon = icon,
       _iconPlacement = iconPlacement,
       _textStyle = textStyle,
       child = null;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final visibility = disabled ? 0.5 : 1.0;
    final buttonContent = _buildContent(context, variant: variant, disabled: disabled);
    final borderRadius = BorderRadius.circular(this.borderRadius);
    final basicBorder = BorderSide(color: context.colors.borderButton, width: 1);

    Color? buttonDecorationColor;
    LinearGradient? buttonDecorationGradient;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case ButtonVariant.primary:
        buttonDecorationColor = context.colors.accentOrange;
        break;

      case ButtonVariant.secondary:
        buttonDecorationGradient = LinearGradient(
          transform: const GradientRotation(90 * math.pi / 180),
          colors: [context.colors.surfaceDeep, context.colors.sheetBackground],
          stops: [0.0, 1.0],
        );
        borderSide = basicBorder.copyWith(color: context.colors.borderButton.useOpacity(0.5));
        break;

      case ButtonVariant.danger:
        buttonDecorationColor = context.colors.buttonDanger;
        break;

      case ButtonVariant.success:
        buttonDecorationColor = context.colors.success;
        break;

      case ButtonVariant.transparent:
        buttonDecorationColor = Colors.transparent;
        break;

      case ButtonVariant.outline:
        buttonDecorationColor = Colors.transparent;
        borderSide = basicBorder;
        break;

      case ButtonVariant.glass:
        buttonDecorationColor = context.colors.surfaceGlass;
        break;

      case ButtonVariant.underline:
        buttonDecorationColor = Colors.transparent;
        break;
    }

    if (variant == ButtonVariant.underline) {
      return InkWell(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: visibility,
          child: Container(width: width, padding: padding, child: buttonContent),
        ),
      );
    }

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: visibility,
        child: Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? context.colors.sheetBackground : buttonDecorationColor,
            gradient: disabled ? null : buttonDecorationGradient,
            shape: RoundedRectangleBorder(borderRadius: borderRadius, side: disabled ? basicBorder : borderSide),
          ),
          child: buttonContent,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {ButtonVariant variant = ButtonVariant.primary, bool disabled = false}) {
    final textColor = switch (variant) {
      ButtonVariant.primary => context.colors.background,
      ButtonVariant.secondary => context.colors.textPrimary,
      ButtonVariant.danger => context.colors.textPrimary,
      ButtonVariant.transparent => context.colors.textPrimary,
      ButtonVariant.success => context.colors.textPrimary,
      ButtonVariant.outline => context.colors.textLabel,
      ButtonVariant.glass => context.colors.textPrimary,
      ButtonVariant.underline => context.colors.textMuted,
    };

    if (isLoading) {
      final size = (_textStyle?.fontSize ?? buttonFontSize) + 6;
      return Center(child: Loader(size: size));
    }

    if (child != null) return child!;

    final effectiveTextStyle = variant == ButtonVariant.underline
        ? _underlineTextStyle(context, textColor)
        : _textStyle ??
              context.themeText.paragraph!.copyWith(
                fontSize: buttonFontSize,
                color: disabled ? context.colors.textPrimary.useOpacity(0.5) : textColor,
                fontWeight: FontWeight.w500,
              );

    Widget content;
    if (_iconPlacement == IconPlacement.top) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          ?_icon,
          Text(_label!, style: effectiveTextStyle),
        ],
      );
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          if (_iconPlacement == IconPlacement.leading && _icon != null) _icon,
          Text(_label!, style: effectiveTextStyle),
          if (_iconPlacement == IconPlacement.trailing && _icon != null) _icon,
        ],
      );
    }

    return Center(child: content);
  }

  /// Underlined link label; a [textStyle] override supplies the color (e.g.
  /// accent orange), everything else stays uniform across links.
  TextStyle _underlineTextStyle(BuildContext context, Color defaultColor) {
    final style = context.themeText.smallParagraph!.copyWith(color: defaultColor).merge(_textStyle);
    return style.copyWith(decoration: TextDecoration.underline, decorationColor: style.color);
  }
}
