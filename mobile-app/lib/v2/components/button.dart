import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

enum ButtonVariant { transparent, primary, secondary, danger }

enum IconPlacement { leading, trailing }

class Button extends StatelessWidget {
  final String label;
  final Icon? icon;
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

    final buttonContent = Center(
      child: isLoading
          ? SizedBox(
              width: (effectiveTextStyle.fontSize ?? buttonFontSize) + 6,
              height: (effectiveTextStyle.fontSize ?? buttonFontSize) + 6,
              child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2.0),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                if (iconPlacement == IconPlacement.leading && icon != null) icon!,
                Text(label, style: effectiveTextStyle),
                if (iconPlacement == IconPlacement.trailing && icon != null) icon!,
              ],
            ),
    );

    Widget buttonWidget;

    switch (variant) {
      case ButtonVariant.primary:
        buttonWidget = LiquidGlassLayer(
          settings: LiquidGlassSettings(
            glassColor: context.colors.surfaceGlass,
            visibility: visibility,
            thickness: 20,
            blur: 4,
            refractiveIndex: 1.33,
            lightAngle: 45 * (3.1416 / 180),
            lightIntensity: 1.0,
            ambientStrength: 0.5,
            saturation: 1.5,
          ),
          child: Center(
            child: LiquidGlass(
              shape: const LiquidRoundedSuperellipse(borderRadius: buttonRadius),
              child: Padding(padding: padding, child: buttonContent),
            ),
          ),
        );
        break;

      case ButtonVariant.secondary:
        buttonWidget = LiquidGlassLayer(
          settings: LiquidGlassSettings(
            visibility: visibility,
            thickness: 20,
            blur: 4,
            refractiveIndex: 1.33,
            lightAngle: 45 * (3.1416 / 180),
            lightIntensity: 1.0,
            ambientStrength: 1.5,
            saturation: 1.5,
          ),
          child: Center(
            child: LiquidGlass(
              shape: const LiquidRoundedSuperellipse(borderRadius: buttonRadius),
              child: Container(
                width: width,
                padding: padding,
                decoration: inset.BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonRadius),
                  boxShadow: [
                    inset.BoxShadow(
                      color: Colors.black.useOpacity(0.3),
                      blurRadius: 56,
                      spreadRadius: -38,
                      offset: const Offset(12, 12),
                      inset: true,
                    ),
                    inset.BoxShadow(
                      color: Colors.white.useOpacity(0.3),
                      blurRadius: 56,
                      spreadRadius: -38,
                      offset: const Offset(-12, -12),
                      inset: true,
                    ),
                  ],
                ),
                child: buttonContent,
              ),
            ),
          ),
        );
        break;

      case ButtonVariant.danger:
        buttonWidget = LiquidGlassLayer(
          settings: LiquidGlassSettings(
            visibility: visibility,
            thickness: 20,
            blur: 4,
            refractiveIndex: 1.33,
            lightAngle: 45 * (3.1416 / 180),
            lightIntensity: 0.5,
            saturation: 1.5,
          ),
          child: Center(
            child: LiquidGlass(
              shape: const LiquidRoundedSuperellipse(borderRadius: buttonRadius),
              child: Container(
                width: width,
                padding: padding,
                decoration: inset.BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonRadius),
                  color: context.colors.buttonDanger,
                  boxShadow: [
                    inset.BoxShadow(
                      color: Colors.black.useOpacity(0.3),
                      blurRadius: 56,
                      spreadRadius: -38,
                      offset: const Offset(12, 12),
                      inset: true,
                    ),
                    inset.BoxShadow(
                      color: Colors.white.useOpacity(0.3),
                      blurRadius: 56,
                      spreadRadius: -38,
                      offset: const Offset(-12, -12),
                      inset: true,
                    ),
                  ],
                  border: BoxBorder.all(color: context.colors.borderDanger, width: 1.5),
                ),
                child: buttonContent,
              ),
            ),
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
}
