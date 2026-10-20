import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Dots joined by hairlines, one per step; done steps are sage, the active one flare.
class SignStepIndicator extends StatelessWidget {
  final List<String> labels;
  final int current;

  const SignStepIndicator({super.key, required this.labels, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) Expanded(child: Container(height: 1, color: colors.borderHairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < current
                        ? colors.semanticSage
                        : i == current
                        ? colors.accentFlare
                        : colors.bgSurface2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  labels[i],
                  style: text.caption.copyWith(color: i == current ? colors.textContent : colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
