import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

enum ButtonVariant { transparent, neutral, primary, success, danger, glass, glassOutline, dangerOutline, accent }

class Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final ButtonVariant variant;
  final bool isDisabled;

  static const double buttonRadius = 50.0;

  const Button({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.textStyle,
    this.variant = ButtonVariant.glass,
    this.isDisabled = false,
  });

  Color? _getTitleColor(BuildContext context, ButtonVariant variant) {
    switch (variant) {
      case ButtonVariant.neutral:
        return context.themeColors.textSecondary;
      case ButtonVariant.accent:
        return Colors.black;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading || isDisabled;

    final effectiveTextStyle = textStyle ?? context.themeText.smallTitle!;
    final disabledBtnColor = context.themeColors.buttonDisabled.useOpacity(0.6);

    final buttonContent = Center(
      child: isLoading
          ? SizedBox(
              width: (effectiveTextStyle.fontSize ?? 16) + 6,
              height: (effectiveTextStyle.fontSize ?? 16) + 6,
              child: CircularProgressIndicator(color: context.themeColors.background, strokeWidth: 2.0),
            )
          : Opacity(
              opacity: disabled ? 0.6 : 1,
              child: Text(
                label,
                style: disabled
                    ? effectiveTextStyle.copyWith(color: Colors.black)
                    : effectiveTextStyle.copyWith(color: _getTitleColor(context, variant)),
              ),
            ),
    );

    Widget buttonWidget;

    switch (variant) {
      case ButtonVariant.primary:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? disabledBtnColor : null,
            gradient: !disabled
                ? LinearGradient(
                    begin: const Alignment(0.00, -1.00),
                    end: const Alignment(0, 1),
                    colors: context.themeColors.buttonPrimary,
                  )
                : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          ),
          child: buttonContent,
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

      case ButtonVariant.neutral:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? disabledBtnColor : context.themeColors.buttonNeutral,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          ),
          child: buttonContent,
        );
        break;

      case ButtonVariant.glassOutline:
        buttonWidget = ClipRRect(
          borderRadius: BorderRadius.circular(buttonRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: width,
              padding: padding,
              decoration: ShapeDecoration(
                color: disabled ? disabledBtnColor : context.themeColors.buttonGlass,
                shape: RoundedRectangleBorder(
                  side: disabled ? BorderSide.none : BorderSide(color: context.themeColors.buttonNeutral),
                  borderRadius: BorderRadius.circular(buttonRadius),
                ),
              ),
              child: buttonContent,
            ),
          ),
        );
        break;

      case ButtonVariant.danger:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? disabledBtnColor : context.themeColors.buttonDanger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          ),
          child: buttonContent,
        );
        break;

      case ButtonVariant.dangerOutline:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
              side: BorderSide(color: disabled ? disabledBtnColor : context.themeColors.buttonDanger, width: 1),
            ),
          ),
          child: Center(
            child: Text(label, style: effectiveTextStyle.copyWith(color: context.themeColors.buttonDanger)),
          ),
        );
        break;

      case ButtonVariant.success:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? disabledBtnColor : context.themeColors.buttonSuccess,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          ),
          child: buttonContent,
        );
        break;

      case ButtonVariant.accent:
        buttonWidget = Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: disabled ? disabledBtnColor : context.colors.accentGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          ),
          child: buttonContent,
        );
        break;

      default:
        buttonWidget = ClipRRect(
          borderRadius: BorderRadius.circular(buttonRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: width,
              padding: padding,
              decoration: ShapeDecoration(
                color: disabled ? disabledBtnColor : context.themeColors.buttonGlass,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              ),
              child: buttonContent,
            ),
          ),
        );
        break;
    }

    return GestureDetector(onTap: disabled ? null : onPressed, child: buttonWidget);
  }
}
