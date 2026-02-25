import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/fading_border_paint.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart' as inset;

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
        buttonWidget = SizedBox(
          width: width, 
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(buttonRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: inset.BoxDecoration(
                      boxShadow: [
                        const inset.BoxShadow(
                          color: Colors.black,
                          blurRadius: 36,
                          spreadRadius: -20,
                          offset: Offset(8, 8),
                          inset: true,
                        ),
                        inset.BoxShadow(
                          color: Colors.white.useOpacity(0.2),
                          blurRadius: 36,
                          spreadRadius: -20,
                          offset: const Offset(-8, -8),
                          inset: true,
                        ),
                      ],
                    ),
                    child: Material(
                      color: context.colors.surfaceGlass,
                      child: Padding(padding: padding, child: buttonContent),
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FadingEdgePainter(
                      borderRadius: buttonRadius,
                      strokeWidth: 1.5,
                      borderColor: context.colors.borderSubtle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        break;

      case ButtonVariant.secondary:
        buttonWidget = Container(
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
            border: BoxBorder.all(color: context.colors.borderSubtle.useOpacity(0.5), width: 1.5),
          ),
          child: buttonContent,
        );
        break;

      case ButtonVariant.danger:
        buttonWidget = ClipRRect(
          borderRadius: BorderRadius.circular(buttonRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
        );
        break;

      case ButtonVariant.transparent:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius))),
          child: buttonContent,
        );
        break;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(opacity: disabled ? 0.2 : 1, child: buttonWidget),
    );
  }
}