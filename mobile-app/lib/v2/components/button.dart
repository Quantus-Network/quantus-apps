import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/inset_button_container.dart';
import 'package:resonance_network_wallet/v2/components/liquid_glass_base.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum ButtonVariant { transparent, primary, secondary, danger }

enum IconPlacement { leading, trailing, top }

class Button extends StatelessWidget {
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

  const Button({
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
  const Button.simple({
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
    final visibility = disabled ? 0.25 : 1.0;
    final buttonContent = _buildContent(context);

    Widget buttonWidget;

    switch (variant) {
      case ButtonVariant.primary:
        buttonWidget = LiquidGlassBase.rounded(
          glassColor: context.colors.surfaceGlass,
          visibility: visibility,
          radius: borderRadius,
          centered: centered,
          child: Padding(padding: padding, child: buttonContent),
        );
        break;

      case ButtonVariant.secondary:
        buttonWidget = LiquidGlassBase.rounded(
          visibility: visibility,
          radius: borderRadius,
          centered: centered,
          child: InsetButtonContainer(
            width: width,
            padding: padding,
            border: BoxBorder.all(color: context.colors.borderSubtle, width: 0.8),
            child: buttonContent,
          ),
        );
        break;

      case ButtonVariant.danger:
        buttonWidget = LiquidGlassBase.rounded(
          visibility: visibility,
          radius: borderRadius,
          centered: centered,
          child: InsetButtonContainer(
            width: width,
            padding: padding,
            backgroundColor: context.colors.buttonDanger,
            border: BoxBorder.all(color: context.colors.borderDanger, width: 1.5),
            child: buttonContent,
          ),
        );
        break;

      case ButtonVariant.transparent:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius))),
          child: Opacity(opacity: visibility, child: buttonContent),
        );
        break;
    }

    return InkWell(onTap: disabled ? null : onTap, child: buttonWidget);
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      final size = (_textStyle?.fontSize ?? buttonFontSize) + 6;
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.0),
        ),
      );
    }

    if (child != null) return child!;

    final effectiveTextStyle = _textStyle ?? context.themeText.smallTitle!.copyWith(fontSize: buttonFontSize);

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
}
