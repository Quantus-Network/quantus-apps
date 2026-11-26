import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/swap/swap_progress.dart';

/// How a swap stands, for what shows it to pick its colour.
enum SwapTone {
  /// With 1Click, on its way.
  running,

  /// Waiting for its deposit by hand.
  awaiting,

  /// Paid out.
  done,

  /// Ended without paying out, but nothing was lost: refunded, or a deposit
  /// that never came or came short.
  caution,

  /// Ended without paying out.
  failed,
}

/// What [swap] is about, as its row says it: the account's side, what it pays
/// or receives, and what for on the other chain ([what]), which is the
/// [foreignAmount] on [network].
({String amount, String foreignAmount, String network, String what}) swapAmountWords(
  AppLocalizations l10n,
  NumberFormattingService fmt,
  ActiveSwap swap,
) {
  final quote = swap.order.quote;
  final swapOut = quote.fromToken.isQuantus;
  final amount = swapOut
      ? '-${formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken)}'
      : '+${formatSwapAmount(l10n, fmt, swap.order.amountOut ?? quote.amountOut, quote.toToken)}';
  final foreign = swapOut ? quote.toToken : quote.fromToken;
  final foreignAmount = formatSwapAmount(l10n, fmt, swapOut ? quote.amountOut : quote.amountIn, foreign);
  return (
    amount: amount,
    foreignAmount: foreignAmount,
    network: foreign.networkName,
    what: l10n.desktopSwapAmountOnNetwork(foreignAmount, foreign.networkName),
  );
}

/// The steps [swap] goes through, as its row names them, and the one it is
/// on ([swapStage]). In [preflight] the stand-in pays out to the recipient,
/// never to the account.
({List<String> steps, int current}) swapStepWords(AppLocalizations l10n, ActiveSwap swap, {required bool preflight}) {
  final quote = swap.order.quote;
  final receiver = quote.fromToken.isQuantus || preflight ? l10n.desktopSwapTheRecipient : swap.accountName;
  return (
    steps: swapStepLabels(l10n, quote, receiver, byHand: swap.depositByHand),
    current: swapStage(swap.order, depositByHand: swap.depositByHand),
  );
}

/// Where [swap] stands in [view], as its row says it: what it is doing or how
/// it ended, the step it is on while it is with 1Click, and its tone. In
/// [preflight] the stand-in pays out to the recipient, never to the account.
({String label, String? step, SwapTone tone}) swapStandingWords(
  AppLocalizations l10n,
  NumberFormattingService fmt,
  ActiveSwap swap,
  SwapProgressView view, {
  required bool preflight,
}) {
  switch (view) {
    case SwapProgressView.inProgress:
      final (:steps, :current) = swapStepWords(l10n, swap, preflight: preflight);
      return (label: l10n.swapStepSwapping, step: steps[current], tone: SwapTone.running);
    case SwapProgressView.deposit:
      return (label: l10n.desktopSwapAwaitingDeposit, step: l10n.desktopSwapWaitingForDeposit, tone: SwapTone.awaiting);
    case SwapProgressView.complete:
      return (label: l10n.swapLiveSwapped, step: null, tone: SwapTone.done);
    case SwapProgressView.failed || SwapProgressView.expired:
      final failure = swapFailureOf(
        l10n,
        fmt,
        swap,
        expired: view == SwapProgressView.expired,
        preflight: preflight,
        addressLabel: (address) => address,
      );
      return (
        label: failure.refunded ? l10n.swapRefundedLabel : failure.title,
        step: null,
        tone: failure.isWarning || failure.refunded ? SwapTone.caution : SwapTone.failed,
      );
  }
}
