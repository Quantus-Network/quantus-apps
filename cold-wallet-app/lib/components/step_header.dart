import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// "STEP n/total" label, screen title and one-paragraph instruction that head
/// each step of the signing flow (Figma Cold Wallet / Receiving, Approve,
/// Transmitting).
class StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String subtitle;

  const StepHeader({super.key, required this.step, required this.total, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP $step/$total', style: text.dataAddress.copyWith(letterSpacing: 0.96, color: colors.accentFlare)),
        const SizedBox(height: 16),
        Text(title, style: text.titleScreen.copyWith(color: colors.textContent)),
        const SizedBox(height: 8),
        Text(subtitle, style: text.body.copyWith(color: colors.textMuted, height: 1.6)),
      ],
    );
  }
}
