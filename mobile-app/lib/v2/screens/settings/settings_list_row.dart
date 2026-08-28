import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsListRow extends StatelessWidget {
  const SettingsListRow({super.key, required this.label, required this.content});

  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyLarge.copyWith(color: colors.accentFlare)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(content, style: text.body.copyWith(color: colors.textMuted)),
        ),
      ],
    );
  }
}
