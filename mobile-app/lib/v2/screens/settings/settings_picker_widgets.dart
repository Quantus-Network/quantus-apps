import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class SettingsPickerSearchField extends StatelessWidget {
  const SettingsPickerSearchField({
    super.key,
    required this.controller,
    required this.colors,
    required this.text,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: colors.textLabel),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: text.smallParagraph,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: text.smallParagraph?.copyWith(color: colors.textLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPickerListTile extends StatelessWidget {
  const SettingsPickerListTile({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.text,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colors.accentOrange;
    final fg = selected ? accent : colors.textPrimary;

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
                child: Text(label, style: text.paragraph?.copyWith(color: fg, height: 1.2)),
              ),
              if (selected) ...[const SizedBox(width: 12), Icon(Icons.check, size: 18, color: accent)],
            ],
          ),
        ),
      ),
    );
  }
}
