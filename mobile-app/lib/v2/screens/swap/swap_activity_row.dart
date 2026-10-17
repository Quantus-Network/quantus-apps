import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Pinned at the top of the home activity while a swap is with 1Click: what
/// is swapped, the step it is on, the dots and the clock. Nothing while a
/// deposit is still to be sent or once the swap settled; the Swap button
/// opens those. A tap opens the swap; [starter] is the account a new one
/// would start from, none where none can.
class SwapActivityRow extends ConsumerWidget {
  final Account? starter;

  /// Masks the amounts, as the feed below does.
  final bool isHidden;

  const SwapActivityRow({super.key, this.starter, this.isHidden = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swap = ref.watch(activeSwapProvider);
    final now = clock.now();
    if (swap == null || !swap.inProgressAt(now)) return const SizedBox.shrink();
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final elapsed = ref.watch(swapElapsedProvider).value ?? swap.elapsedAt(now);
    final quote = swap.order.quote;
    final stage = swapStage(swap.order, depositByHand: swap.depositByHand);
    final receiver = swapReceiver(swap, preflight: ref.watch(swapPreflightProvider) != null);
    final step = swapStepLabels(l10n, quote, receiver, byHand: swap.depositByHand)[stage];
    final label = isHidden
        ? l10n.swapInProgressTitle
        : l10n.swapActivityAmounts(
            formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken),
            formatSwapAmount(l10n, fmt, quote.amountOut, quote.toToken),
          );

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwapProgressScreen(account: starter))),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: glacierFill(colors),
                    borderRadius: context.radiusV3.xsBorder,
                    border: Border.all(color: glacierStroke(colors), width: 1.5),
                  ),
                  child: QuantusIcon(QuantusIcons.swapVertical, size: 14, color: colors.semanticGlacier),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.bodyLarge.copyWith(color: colors.textContent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step,
                        style: text.caption.copyWith(color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatSwapElapsed(elapsed), style: text.bodyLarge.copyWith(color: colors.textContent)),
                    const SizedBox(height: 8),
                    SwapProgressDots(stage: stage),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: colors.borderHairline, height: 1),
        ],
      ),
    );
  }
}
