import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Slider for choosing how many signer approvals a multisig proposal needs.
class MultisigThresholdSlider extends StatelessWidget {
  const MultisigThresholdSlider({
    super.key,
    required this.threshold,
    required this.signerCount,
    required this.label,
    required this.valueLabel,
    required this.onChanged,
  });

  final int threshold;
  final int signerCount;
  final String label;
  final String valueLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final maxThreshold = signerCount < 1 ? 1 : signerCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
              ),
              Text(
                valueLabel,
                style: text.paragraph?.copyWith(
                  color: colors.accentOrange,
                  fontFamily: AppTextTheme.fontFamilySecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.accentOrange,
              inactiveTrackColor: colors.borderButton,
              thumbColor: colors.accentOrange,
              overlayColor: colors.accentOrange.useOpacity(0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: threshold.toDouble(),
              min: 1,
              max: maxThreshold.toDouble(),
              divisions: maxThreshold > 1 ? maxThreshold - 1 : null,
              onChanged: signerCount < 2 ? null : (value) => onChanged(value.round()),
            ),
          ),
        ],
      ),
    );
  }
}
