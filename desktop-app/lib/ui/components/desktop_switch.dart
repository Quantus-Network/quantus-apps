import 'package:flutter/cupertino.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// An on/off switch at desktop size, in the accent colour. Tab reaches it and
/// Space flips it; a screen reader calls it [label].
class DesktopSwitch extends StatelessWidget {
  const DesktopSwitch({super.key, required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 24,
      child: FittedBox(
        child: Semantics(
          label: label,
          child: CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: context.colorsV3.accentFlare,
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
          ),
        ),
      ),
    );
  }
}
