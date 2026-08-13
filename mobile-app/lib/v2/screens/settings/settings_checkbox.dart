import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String label;

  const SettingsCheckbox({super.key, required this.checked, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    final borderColor = checked ? colors.accentOrange : colors.borderButton;
    final labelStyle = text.paragraph?.copyWith(color: colors.textMuted, fontSize: 16);
    final double kSettingsSquareCheckboxSize = 20;
    final double kSettingsSquareCheckboxRadius = 4;
    final double kSettingsSquareCheckboxCheckSize = 14;

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
                  color: checked ? colors.accentOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(kSettingsSquareCheckboxRadius),
                  border: Border.all(color: borderColor, width: 1),
                ),
                alignment: Alignment.center,
                child: checked
                    ? Icon(Icons.check, size: kSettingsSquareCheckboxCheckSize, color: colors.background)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: labelStyle)),
            ],
          ),
        ),
      ),
    );
  }
}
