import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// How much of an animated QR has arrived: [label], the frame count once the
/// [total] is known, and a bar (Figma Sign with Cold Wallet, step 3/3).
class ScanProgress extends StatelessWidget {
  final String label;
  final int scanned;
  final int? total;

  const ScanProgress({super.key, required this.label, required this.scanned, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final style = context.themeTextV3.dataAddress.copyWith(letterSpacing: 0.96);
    final total = this.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style.copyWith(color: colors.textMuted)),
            if (total != null) Text('$scanned/$total', style: style.copyWith(color: colors.textWhite)),
          ],
        ),
        ClipRRect(
          borderRadius: context.radiusV3.xsBorder,
          child: LinearProgressIndicator(
            value: total == null ? 0 : (scanned / total).clamp(0, 1).toDouble(),
            minHeight: 4,
            backgroundColor: colors.bgSurface2,
            color: colors.accentFlare,
          ),
        ),
      ],
    );
  }
}
