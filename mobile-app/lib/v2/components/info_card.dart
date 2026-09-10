import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A surface row with a leading badge, a heading and a short description.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.leading, required this.title, required this.description});

  final Widget leading;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
                const SizedBox(height: 4),
                Text(description, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
