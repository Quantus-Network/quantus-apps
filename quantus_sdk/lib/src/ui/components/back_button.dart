import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// 28pt glass chevron with a [hitSize] square tap target; the visual sits at
/// the left edge so the extra area extends right, above and below it.
class AppBackButton extends StatelessWidget {
  static const double hitSize = 48;

  final VoidCallback? onTap;

  const AppBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    const double containerSize = 28;
    const double iconSize = 24;

    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Align(
          alignment: Alignment.centerLeft,
          child: GlassButtonBase(
            buttonHeight: containerSize,
            buttonWidth: containerSize,
            borderRadius: BorderRadius.circular(containerSize / 2),
            padding: const EdgeInsets.all(2),
            child: QuantusIcon(QuantusIcons.chevronLeft, size: iconSize, color: context.colorsV3.textContent),
          ),
        ),
      ),
    );
  }
}
