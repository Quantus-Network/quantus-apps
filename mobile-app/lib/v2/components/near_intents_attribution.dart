import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';

/// "Powered By / near Intents" lockup from the swap header design: white at 32%, right-aligned.
class NearIntentsAttribution extends ConsumerWidget {
  static const double width = 90;

  const NearIntentsAttribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.colorsV3.textWhite.useOpacity(0.32);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            ref.watch(l10nProvider).swapPoweredBy,
            style: context.themeTextV3.labelChip.copyWith(fontSize: 10, height: 1.2, color: color),
          ),
          const SizedBox(height: 4),
          Image.asset(
            'assets/v2/near_intents_logo.png',
            width: width,
            height: 11,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            semanticLabel: 'NEAR Intents',
          ),
        ],
      ),
    );
  }
}
