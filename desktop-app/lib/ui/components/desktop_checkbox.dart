import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A checkbox with its label beside it, at desktop size. A click on the
/// label ticks it too; Tab reaches it and Space ticks it.
class DesktopCheckbox extends StatelessWidget {
  const DesktopCheckbox({super.key, required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return MergeSemantics(
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: colors.accentFlare,
            checkColor: colors.textVoid,
            side: BorderSide(color: colors.borderEmphasis),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            mouseCursor: SystemMouseCursors.basic,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: Text(label, style: context.themeTextV3.body.copyWith(color: colors.textContent)),
            ),
          ),
        ],
      ),
    );
  }
}
