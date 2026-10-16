import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';

/// The steps a swap goes through, as the progress screen lists them.
List<String> swapStepLabels(AppLocalizations l10n, SwapQuote quote, String receiver) => [
  l10n.swapStepSent(quote.fromToken.symbol),
  l10n.swapStepConfirming(quote.fromToken.networkName),
  l10n.swapStepSwapping,
  l10n.swapStepSending(quote.toToken.symbol, receiver),
];

const swapStepCount = 4;

/// Index of the step [order] is on; the steps before it are done. A swap
/// that succeeded is past them all, one that stopped stays on the step it
/// stopped at.
int swapStage(SwapOrder order, {required bool depositByHand}) => switch (order.status) {
  SwapStatus.pendingDeposit => depositByHand ? 0 : 1,
  SwapStatus.knownDepositTx || SwapStatus.incompleteDeposit => 1,
  SwapStatus.processing || SwapStatus.refunded || SwapStatus.failed => 2,
  SwapStatus.success => swapStepCount,
};

/// [elapsed] as "m:ss", e.g. "3:07", or "h:mm:ss" from an hour on.
String formatSwapElapsed(Duration elapsed) {
  final f = DatetimeFormattingService.formatDuration(elapsed);
  return elapsed.inHours == 0 ? '${elapsed.inMinutes}:${f.seconds}' : '${elapsed.inHours}:${f.minutes}:${f.seconds}';
}

/// Lives on the home swap button while a swap runs: one dot per step, lit
/// for the steps reached, and how long the swap has been running.
class SwapProgressBadge extends ConsumerWidget {
  final ActiveSwap swap;

  const SwapProgressBadge({super.key, required this.swap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final elapsed = ref.watch(swapElapsedProvider).value ?? swap.elapsedAt(clock.now());
    final stage = swapStage(swap.order, depositByHand: swap.depositByHand);
    final failed = swap.isFinal && swap.order.status != SwapStatus.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bgVoid,
        borderRadius: context.radiusV3.pillBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwapProgressDots(stage: stage, failed: failed),
          const SizedBox(width: 5),
          Text(
            formatSwapElapsed(elapsed),
            style: text.labelMonogram.copyWith(fontSize: 10, height: 1, color: colors.textContent),
          ),
        ],
      ),
    );
  }
}

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
