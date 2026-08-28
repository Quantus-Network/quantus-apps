import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String label;

  const SettingsCheckbox({super.key, required this.checked, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final borderColor = checked ? colors.accentFlare : colors.borderHairline;
    const double kSettingsSquareCheckboxSize = 20;
    const double kSettingsSquareCheckboxCheckSize = 14;

    return Semantics(
      checked: checked,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: kSettingsSquareCheckboxSize,
                height: kSettingsSquareCheckboxSize,
                decoration: BoxDecoration(
                  color: checked ? colors.accentFlare : Colors.transparent,
                  borderRadius: context.radiusV3.xsBorder,
                  border: Border.all(color: borderColor, width: 1),
                ),
                alignment: Alignment.center,
                child: checked
                    ? Icon(Icons.check, size: kSettingsSquareCheckboxCheckSize, color: colors.textVoid)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: text.body.copyWith(color: colors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
