import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsPickerListTile extends StatelessWidget {
  const SettingsPickerListTile({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fg = selected ? colors.accentFlare : colors.textContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(label, style: text.body.copyWith(color: fg)),
              ),
              if (selected) ...[const SizedBox(width: 12), Icon(Icons.check, size: 18, color: colors.accentFlare)],
            ],
          ),
        ),
      ),
    );
  }
}
