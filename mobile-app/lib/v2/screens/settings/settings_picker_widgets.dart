import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsPickerSearchField extends StatelessWidget {
  const SettingsPickerSearchField({super.key, required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: text.body.copyWith(color: colors.textContent),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: text.body.copyWith(color: colors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
