import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The scheme's name as the picker and the disconnect dialog show it.
String schemeLabel(DilithiumScheme scheme) => scheme == DilithiumScheme.mlDsa65 ? 'ML-DSA-65' : 'ML-DSA-87';

/// Signature-scheme choice for an account: ML-DSA-87 (the default for new
/// accounts, first) or ML-DSA-65.
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
          items: [
            for (final scheme in [DilithiumScheme.mlDsa87, DilithiumScheme.mlDsa65])
              SegmentedControlItem(value: scheme, label: schemeLabel(scheme)),
          ],
        ),
      ],
    );
  }
}
