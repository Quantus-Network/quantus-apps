import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// The steps a swap goes through, as the progress screen lists them; a
/// deposit made [byHand] is deposited rather than sent.
List<String> swapStepLabels(AppLocalizations l10n, SwapQuote quote, String receiver, {required bool byHand}) => [
  byHand ? l10n.swapStepDeposited(quote.fromToken.symbol) : l10n.swapStepSent(quote.fromToken.symbol),
  l10n.swapStepConfirming(quote.fromToken.networkName),
  l10n.swapStepSwapping,
  l10n.swapStepSending(quote.toToken.symbol, receiver),
];

const swapStepCount = 4;

/// Who the swap pays out to, as the steps name it: the account for a swap
/// into QTC, else the recipient address, as in [preflight] always.
String swapReceiver(ActiveSwap swap, {required bool preflight}) {
  final quote = swap.order.quote;
  return quote.fromToken.isQuantus || preflight
      ? AddressFormattingService.formatAddress(quote.recipient)
      : swap.accountName;
}

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
