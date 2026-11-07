import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Glass circle of [size] holding a chevron, or another [icon], inside a
/// [hitSize] square tap target; the visual sits at the left edge so the extra
/// area extends right, above and below it.
class AppBackButton extends StatelessWidget {
  static const double hitSize = 48;

  final VoidCallback? onTap;
  final QuantusIcons icon;
  final double size;
  final double iconSize;

  const AppBackButton({
    super.key,
    this.onTap,
    this.icon = QuantusIcons.chevronLeft,
    this.size = 28,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Align(
          alignment: Alignment.centerLeft,
          child: GlassButtonBase(
            buttonHeight: size,
            buttonWidth: size,
            borderRadius: BorderRadius.circular(size / 2),
            padding: EdgeInsets.all((size - iconSize) / 2),
            child: QuantusIcon(icon, size: iconSize, color: context.colorsV3.textContent),
          ),
        ),
      ),
    );
  }
}
