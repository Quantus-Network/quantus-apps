import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

enum _ColdButtonKind { secondary, danger }

/// The two Figma Cold Wallet buttons the SDK has no variant for: the second
/// choice beside a primary (card gradient, emphasis border) and the
/// destructive action (ember tint, ember label). Null [onTap] disables it.
class ColdButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final _ColdButtonKind _kind;

  const ColdButton.secondary({super.key, required this.label, required this.onTap, this.padding = coldButtonPadding})
    : _kind = _ColdButtonKind.secondary;

  const ColdButton.danger({super.key, required this.label, required this.onTap, this.padding = coldButtonPadding})
    : _kind = _ColdButtonKind.danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.mdBorder;
    final disabled = onTap == null;

    final (ShapeDecoration decoration, Color textColor) = switch (_kind) {
      _ColdButtonKind.secondary when disabled => (
        ShapeDecoration(
          color: colors.bgSurface2,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        colors.textMuted2,
      ),
      _ColdButtonKind.secondary => (
        ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.bgCardGradientTop, colors.bgCardGradientBottom],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.borderEmphasis),
          ),
        ),
        colors.textContent,
      ),
      _ColdButtonKind.danger => (
        ShapeDecoration(
          color: colors.semanticEmber.useOpacity(0.10),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.semanticEmber.useOpacity(0.25)),
          ),
        ),
        colors.semanticEmber,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Opacity(
        opacity: disabled && _kind == _ColdButtonKind.danger ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: decoration,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.themeTextV3.headingRow.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
