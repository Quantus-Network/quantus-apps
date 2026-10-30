import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Kebab glyph with a 44pt target, for an app bar slot or a list row.
class KebabButton extends StatelessWidget {
  final VoidCallback onTap;

  const KebabButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: QuantusIcon(QuantusIcons.kebab, size: 20, color: context.colorsV3.textContent)),
      ),
    );
  }
}
