import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

enum ButtonVariant {
  transparent,
  primary,
  secondary,
  danger,
  outline,
  glass,
  underline,

  /// Not-yet-ready primary: surface fill and emphasis border.
  staged,

  /// Escape route: no fill or border, muted label.
  ghost,
}

enum IconPlacement { leading, trailing, top }

class QuantusButton extends StatelessWidget {
  final Widget? child;
  final String? _label;
  final Widget? _icon;
  final IconPlacement _iconPlacement;
  final TextStyle? _textStyle;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? width;
  final EdgeInsets padding;
  final ButtonVariant variant;
  final bool isDisabled;
  final bool centered;

  const QuantusButton({
    super.key,
    required Widget this.child,
    this.onTap,
    this.borderRadius,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.variant = ButtonVariant.primary,
    this.isDisabled = false,
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
    this.borderRadius,
    this.isLoading = false,
    this.width = double.infinity,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
    TextStyle? textStyle,
    this.variant = ButtonVariant.primary,
    this.isDisabled = false,
    this.centered = true,
  }) : _label = label,
       _icon = icon,
       _iconPlacement = iconPlacement,
       _textStyle = textStyle,
       child = null;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading || isDisabled;
    final chrome = _chrome(context, disabled: disabled);
    final buttonContent = _buildContent(context, textColor: chrome.textColor);
    final borderRadius = this.borderRadius ?? context.radiusV3.mdBorder;

    if (variant == ButtonVariant.underline) {
      return InkWell(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: chrome.opacity,
          child: Container(width: width, padding: padding, child: buttonContent),
        ),
      );
    }

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: chrome.opacity,
        child: Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            color: chrome.color,
            gradient: chrome.gradient,
            shape: RoundedRectangleBorder(borderRadius: borderRadius, side: chrome.borderSide),
          ),
          child: buttonContent,
        ),
      ),
    );
  }

  _ButtonChrome _chrome(BuildContext context, {required bool disabled}) {
    final colors = context.colorsV3;
    final basicBorder = BorderSide(color: colors.borderEmphasis, width: 1);

    if (disabled && (variant == ButtonVariant.primary || variant == ButtonVariant.staged)) {
      return _ButtonChrome(color: colors.bgSurface2, textColor: colors.textMuted2);
    }

    final enabled = switch (variant) {
      ButtonVariant.primary => _ButtonChrome(color: colors.accentFlare, textColor: colors.textVoid),
      ButtonVariant.staged => _ButtonChrome(
        color: colors.bgSurface,
        borderSide: basicBorder,
        textColor: colors.textContent,
      ),
      ButtonVariant.ghost => _ButtonChrome(
        color: Colors.transparent,
        textColor: disabled ? colors.textMuted2 : colors.textMuted,
      ),
      ButtonVariant.secondary => _ButtonChrome(
        gradient: LinearGradient(
          transform: const GradientRotation(90 * math.pi / 180),
          colors: [context.colors.surfaceDeep, context.colors.sheetBackground],
          stops: [0.0, 1.0],
        ),
        borderSide: basicBorder.copyWith(color: context.colors.borderButton.useOpacity(0.5)),
        textColor: colors.textContent,
      ),
      ButtonVariant.danger => _ButtonChrome(color: context.colors.buttonDanger, textColor: colors.textContent),
      ButtonVariant.transparent => _ButtonChrome(color: Colors.transparent, textColor: colors.textContent),
      ButtonVariant.outline => _ButtonChrome(
        color: Colors.transparent,
        borderSide: basicBorder,
        textColor: colors.textContent,
      ),
      ButtonVariant.glass => _ButtonChrome(color: context.colors.surfaceGlass, textColor: colors.textContent),
      ButtonVariant.underline => _ButtonChrome(
        color: Colors.transparent,
        opacity: disabled ? 0.5 : 1.0,
        textColor: colors.textMuted,
      ),
    };

    final usesLegacyDisabled =
        disabled &&
        variant != ButtonVariant.primary &&
        variant != ButtonVariant.staged &&
        variant != ButtonVariant.ghost &&
        variant != ButtonVariant.underline;
    if (usesLegacyDisabled) {
      return _legacyDisabledChrome(context, basicBorder);
    }

    return enabled;
  }

  _ButtonChrome _legacyDisabledChrome(BuildContext context, BorderSide basicBorder) {
    return _ButtonChrome(
      color: context.colors.sheetBackground,
      borderSide: basicBorder,
      opacity: 0.5,
      textColor: context.colors.textPrimary.useOpacity(0.5),
    );
  }

  Widget _buildContent(BuildContext context, {required Color textColor}) {
    final defaultTextStyle = context.themeTextV3.headingRow;

    if (isLoading) {
      final size = (_textStyle?.fontSize ?? defaultTextStyle.fontSize!) + 6;
      return Center(child: Loader(size: size));
    }

    if (child != null) return child!;

    final effectiveTextStyle = variant == ButtonVariant.underline
        ? _underlineTextStyle(context, textColor)
        : _textStyle ?? defaultTextStyle.copyWith(color: textColor);

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
          Flexible(
            child: Text(_label!, textAlign: TextAlign.center, style: effectiveTextStyle),
          ),
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

class _ButtonChrome {
  final Color? color;
  final LinearGradient? gradient;
  final BorderSide borderSide;
  final double opacity;
  final Color textColor;

  const _ButtonChrome({
    this.color,
    this.gradient,
    this.borderSide = BorderSide.none,
    this.opacity = 1.0,
    required this.textColor,
  });
}
