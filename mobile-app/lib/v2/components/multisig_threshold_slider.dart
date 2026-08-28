import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final maxThreshold = signerCount < 1 ? 1 : signerCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: text.labelData.copyWith(color: colors.textMuted)),
              ),
              Text(valueLabel, style: text.labelData.copyWith(color: colors.accentFlare)),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.accentFlare,
              inactiveTrackColor: colors.borderHairline,
              thumbColor: colors.accentFlare,
              overlayColor: colors.accentFlare.useOpacity(0.15),
              trackHeight: 2,
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
