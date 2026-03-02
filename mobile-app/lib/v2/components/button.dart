import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/inset_button_container.dart';
import 'package:resonance_network_wallet/v2/components/liquid_glass_base.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum ButtonVariant { transparent, primary, secondary, danger }

enum IconPlacement { leading, trailing, top }

class Button extends StatelessWidget {
  final String label;
  final Widget? icon;
  final IconPlacement iconPlacement;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? width;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final ButtonVariant variant;
  final bool isDisabled;

  static const double buttonRadius = 14.0;
  static const double buttonFontSize = 16.0;

  const Button({
    super.key,
    required this.label,
    this.icon,
    this.iconPlacement = IconPlacement.trailing,
    this.onTap,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
    this.textStyle,
    this.variant = ButtonVariant.primary,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final effectiveTextStyle = textStyle ?? context.themeText.smallTitle!.copyWith(fontSize: buttonFontSize);
    final visibility = disabled ? 0.25 : 1.0;

    final buttonContent = _buildContent(context, effectiveTextStyle: effectiveTextStyle);

    Widget buttonWidget;

    switch (variant) {
      case ButtonVariant.primary:
        buttonWidget = LiquidGlassBase.rounded(
          glassColor: context.colors.surfaceGlass,
          visibility: visibility,
          child: Padding(padding: padding, child: buttonContent),
        );
        break;

      case ButtonVariant.secondary:
        buttonWidget = LiquidGlassBase.rounded(
          visibility: visibility,
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
          decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius))),
          child: Opacity(opacity: visibility, child: buttonContent),
        );
        break;
    }

    return InkWell(onTap: disabled ? null : onTap, child: buttonWidget);
  }

  Widget _buildContent(BuildContext context, {required TextStyle effectiveTextStyle}) {
    Widget content;

    if (isLoading) {
      content = SizedBox(
        width: (effectiveTextStyle.fontSize ?? buttonFontSize) + 6,
        height: (effectiveTextStyle.fontSize ?? buttonFontSize) + 6,
        child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.0),
      );
    } else if (iconPlacement == IconPlacement.top) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          ?icon,
          Text(label, style: effectiveTextStyle),
        ],
      );
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          if (iconPlacement == IconPlacement.leading && icon != null) icon!,
          Text(label, style: effectiveTextStyle),
          if (iconPlacement == IconPlacement.trailing && icon != null) icon!,
        ],
      );
    }

    return Center(child: content);
  }
}
