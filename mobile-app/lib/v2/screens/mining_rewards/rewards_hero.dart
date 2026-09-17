import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Uppercase label over a large amount with a muted unit, as on the rewards,
/// pay-to and submitted pages.
class RewardsHero extends StatelessWidget {
  final String label;
  final String amount;
  final String unit;
  final Color? amountColor;

  const RewardsHero({super.key, required this.label, required this.amount, required this.unit, this.amountColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: text.labelData.copyWith(color: colors.textMuted)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(amount, style: text.displayBalance.copyWith(color: amountColor ?? colors.textContent)),
            const SizedBox(width: 8),
            Text(unit, style: text.bodyLarge.copyWith(color: colors.textMuted)),
          ],
        ),
      ],
    );
  }
}
