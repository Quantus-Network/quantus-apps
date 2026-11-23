import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/swap/swap_progress.dart';

/// One dot per swap step: sage up to [stage], ember instead when the swap
/// [failed], grey for the steps not reached.
class SwapProgressDots extends StatelessWidget {
  static const dotSize = 5.0;

  final int stage;
  final bool failed;

  const SwapProgressDots({super.key, required this.stage, this.failed = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final reached = failed ? colors.semanticEmber : colors.semanticSage;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        for (var i = 0; i < swapStepCount; i++)
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: i <= stage ? reached : colors.bgSurface2, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
