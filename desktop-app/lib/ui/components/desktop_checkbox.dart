import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A checkbox with its label beside it, at desktop size. A click on the
/// label ticks it too; Tab reaches it and Space ticks it. With no
/// [onChanged] it is dimmed and does none of this.
class DesktopCheckbox extends StatelessWidget {
  const DesktopCheckbox({super.key, required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;

  /// What a tick or an untick reports. Null makes the checkbox unavailable.
  final ValueChanged<bool>? onChanged;

  /// The side of the room the box takes, with the clear space around it.
  static const double boxExtent = 32;

  /// The clear space on each side of the box. A checkbox that is to lie on
  /// the content's edge, top or left, is moved out by this much.
  static const double boxInset = (boxExtent - Checkbox.width) / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final onChanged = this.onChanged;

    return MergeSemantics(
      child: Opacity(
        opacity: onChanged == null ? 0.4 : 1,
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged == null ? null : (value) => onChanged(value ?? false),
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
                onTap: onChanged == null ? null : () => onChanged(!value),
                child: Text(label, style: context.themeTextV3.body.copyWith(color: colors.textContent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
