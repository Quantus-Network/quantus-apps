import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/active_swaps_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/screens/activity/tx_item.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Pinned at the top of the home activity: one row per followed swap, newest
/// first, except a swap still waiting for its deposit to be sent. A running
/// swap shows the step it is on, its dots and its clock; a settled one says
/// so until it is opened and put away. A tap opens the swap; [starter] is the
/// account a new swap would start from, none where none can.
class SwapActivityRows extends ConsumerWidget {
  final Account? starter;

  /// Masks the amounts, as the feed below does.
  final bool isHidden;

  const SwapActivityRows({super.key, this.starter, this.isHidden = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final swaps = ref
        .watch(activeSwapsProvider)
        .where((s) => s.depositUnderway || s.order.status != SwapStatus.pendingDeposit)
        .toList()
        .reversed;
    if (swaps.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(swapClockProvider).value ?? clock.now();
    return Column(
      children: [for (final swap in swaps) _SwapRow(swap: swap, now: now, starter: starter, isHidden: isHidden)],
    );
  }
}

class _SwapRow extends ConsumerWidget {
  final ActiveSwap swap;
  final DateTime now;
  final Account? starter;
  final bool isHidden;

  const _SwapRow({required this.swap, required this.now, required this.starter, required this.isHidden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final order = swap.order;
    final quote = order.quote;
    final stage = swapStage(order, depositByHand: swap.depositByHand);
    final failed = swap.isFinal && order.status != SwapStatus.success;
    final label = isHidden
        ? l10n.swapActivityAmounts(hiddenAmountText, hiddenAmountText)
        : l10n.swapActivityAmounts(
            formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken),
            formatSwapAmount(l10n, fmt, order.amountOut ?? quote.amountOut, quote.toToken),
          );
    final String state;
    if (order.status == SwapStatus.success) {
      state = l10n.swapCompleteTitle;
    } else if (failed) {
      state = l10n.swapFailedTitle;
    } else if (swap.overdue(now)) {
      state = l10n.swapActivityOverdue;
    } else {
      final receiver = swapReceiver(swap, preflight: ref.watch(swapPreflightProvider) != null);
      state = swapStepLabels(l10n, quote, receiver, byHand: swap.depositByHand)[stage];
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SwapProgressScreen(swapId: swap.id, account: starter),
        ),
      ),
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
                        state,
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
                    Text(
                      formatSwapElapsed(swap.elapsedAt(now)),
                      style: text.bodyLarge.copyWith(color: colors.textContent),
                    ),
                    const SizedBox(height: 8),
                    SwapProgressDots(stage: stage, failed: failed),
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
