import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Signature-scheme choice for an account: ML-DSA-65 (current) or ML-DSA-87.
class SchemePicker extends StatelessWidget {
  final DilithiumScheme value;
  final ValueChanged<DilithiumScheme> onChanged;

  const SchemePicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SIGNATURE TYPE', style: text.labelMonogram.copyWith(color: colors.textMuted)),
        const SizedBox(height: 8),
        SegmentedControls<DilithiumScheme>(
          selectedValue: value,
          onChanged: onChanged,
          items: const [
            SegmentedControlItem(value: DilithiumSchemeExtension.current, label: 'ML-DSA-65'),
            SegmentedControlItem(value: DilithiumSchemeExtension.legacy, label: 'ML-DSA-87'),
          ],
        ),
      ],
    );
  }
}
