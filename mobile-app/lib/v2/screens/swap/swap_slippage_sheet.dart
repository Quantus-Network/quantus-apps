import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Picks the slippage tolerance for the next quote; closes on a pick.
Future<void> showSwapSlippageSheet(BuildContext context) =>
    BottomSheetContainer.show<void>(context, builder: (_) => const _SwapSlippageSheet());

class _SwapSlippageSheet extends ConsumerWidget {
  const _SwapSlippageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return BottomSheetContainer(
      title: l10n.swapSlippageTitle,
      trailing: QuantusIconButton.ghost(
        icon: Icons.close,
        onTap: () => Navigator.pop(context),
        size: IconButtonSize.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.swapSlippageBody, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 24),
          SegmentedControls<int>(
            items: [
              for (final bps in swapSlippageOptionsBps)
                SegmentedControlItem(value: bps, label: l10n.swapSlippagePercent(slippagePercentLabel(bps))),
            ],
            selectedValue: ref.watch(swapSlippageBpsProvider),
            onChanged: (bps) {
              ref.read(swapSlippageBpsProvider.notifier).state = bps;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
