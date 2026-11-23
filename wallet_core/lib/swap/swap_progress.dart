import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/swap_providers.dart';

/// The steps a swap goes through, as its progress lists them; a deposit made
/// [byHand] is deposited rather than sent.
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

/// What a followed swap shows.
enum SwapProgressView {
  /// Where to send the deposit, while one made by hand is awaited.
  deposit,

  /// The steps, while the swap is with 1Click.
  inProgress,

  /// What arrived where.
  complete,

  /// How it ended without paying out: refunded, failed or short-paid.
  failed,

  /// The deposit window closed with no deposit sent.
  expired,
}

/// The view [swap] shows at [now]. A deposit to be made by hand is awaited
/// until it is marked sent, and has expired once its deadline passes; one the
/// app sent is on its way from the start.
SwapProgressView swapProgressViewOf(ActiveSwap swap, DateTime now) {
  final order = swap.order;
  final awaitingDeposit = order.status == SwapStatus.pendingDeposit && !swap.depositUnderway;
  final expired = awaitingDeposit && now.isAfter(order.quote.deadline);
  return switch (order.status) {
    SwapStatus.success => SwapProgressView.complete,
    SwapStatus.refunded || SwapStatus.failed || SwapStatus.incompleteDeposit => SwapProgressView.failed,
    _ when expired => SwapProgressView.expired,
    _ when awaitingDeposit => SwapProgressView.deposit,
    _ => SwapProgressView.inProgress,
  };
}

/// How a swap that paid nothing out ended, in words.
@immutable
class SwapFailure {
  const SwapFailure({required this.title, required this.message, required this.refunded, required this.isWarning});

  final String title;
  final String message;

  /// Whether what was paid went back.
  final bool refunded;

  /// Whether it is a caution rather than a failure: the deposit never came,
  /// or came short and is refunded after the deadline.
  final bool isWarning;
}

/// How [swap] ended without paying out: refunded, failed, short-paid, or,
/// when [expired], a deposit window that closed with nothing sent. An address
/// outside the wallet is named by [addressLabel], each app in its own way; in
/// [preflight] the stand-in's refund address is one.
SwapFailure swapFailureOf(
  AppLocalizations l10n,
  NumberFormattingService fmt,
  ActiveSwap swap, {
  required bool expired,
  required bool preflight,
  required String Function(String address) addressLabel,
}) {
  final order = swap.order;
  final quote = order.quote;
  final from = quote.fromToken;
  final String message;
  if (expired) {
    message = l10n.swapDepositExpiredBody;
  } else {
    message = switch (order.status) {
      SwapStatus.refunded => [
        l10n.swapRefundedBody(
          formatSwapAmount(l10n, fmt, order.refundedAmount ?? quote.amountIn, from),
          from.isQuantus && !preflight ? swap.accountName : addressLabel(quote.refundAddress),
          quote.toToken.symbol,
        ),
        if (order.refundReason != null) l10n.swapDepositRefundReason(order.refundReason!),
      ].join('\n\n'),
      SwapStatus.incompleteDeposit => l10n.swapDepositIncompleteBody,
      _ => l10n.swapDepositFailedBody(order.depositAddress),
    };
  }
  return SwapFailure(
    title: expired
        ? l10n.swapDepositExpiredTitle
        : order.status == SwapStatus.incompleteDeposit
        ? l10n.swapDepositIncompleteTitle
        : l10n.swapFailedTitle,
    message: message,
    refunded: order.status == SwapStatus.refunded,
    isWarning: expired || order.status == SwapStatus.incompleteDeposit,
  );
}
