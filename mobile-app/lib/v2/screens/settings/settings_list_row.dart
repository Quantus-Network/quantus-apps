import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsListRow extends StatelessWidget {
  const SettingsListRow({super.key, required this.label, required this.content});

  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    final text = context.themeText;
    final colors = context.colors;

    final bodyStyle = text.paragraph?.copyWith(color: colors.textMuted);
    final numStyle = text.paragraph?.copyWith(
      fontFamily: AppTextTheme.fontFamilySecondary,
      color: colors.accentOrange,
      height: 1.35,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: numStyle),
        const SizedBox(width: 16),
        Expanded(child: Text(content, style: bodyStyle)),
      ],
    );
  }
}
