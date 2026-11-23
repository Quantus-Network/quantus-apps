import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/swap_providers.dart';

/// One line of a swap's terms: a [label] and what stands beside it. What the
/// lines hold is said here; each app draws them its own way.
@immutable
sealed class SwapRow {
  const SwapRow(this.label);

  final String label;
}

/// A figure or other short text.
class SwapRowText extends SwapRow {
  const SwapRowText(super.label, this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is SwapRowText && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);

  @override
  String toString() => 'SwapRowText($label, $value)';
}

/// An [address], whole: on another chain, or the account's own in preflight.
/// An app shortens it or not as it does its addresses.
class SwapRowAddress extends SwapRow {
  const SwapRowAddress(super.label, this.address);

  final String address;

  @override
  bool operator ==(Object other) => other is SwapRowAddress && other.label == label && other.address == address;

  @override
  int get hashCode => Object.hash(label, address);

  @override
  String toString() => 'SwapRowAddress($label, $address)';
}

/// The fees [quote]'s amounts already hold: what its fee recipients take of
/// the payment, and 1Click's fixed fee for paying out. A fee the quote does
/// not carry has no row.
List<SwapRowText> swapQuoteFeeRowsOf(AppLocalizations l10n, NumberFormattingService fmt, SwapQuote quote) => [
  if (quote.feeBps > 0)
    SwapRowText(
      l10n.swapReviewSwapFee,
      l10n.swapReviewSlippageValue(
        formatSwapAmount(l10n, fmt, quote.feeAmount, quote.fromToken),
        slippagePercentLabel(quote.feeBps),
      ),
    ),
  if (quote.withdrawFee > BigInt.zero)
    SwapRowText(l10n.swapReviewWithdrawalFee, formatSwapAmount(l10n, fmt, quote.withdrawFee, quote.toToken)),
];

/// A quote's terms as its review lists them, and whether it can be confirmed.
@immutable
class SwapReview {
  const SwapReview({
    required this.rows,
    required this.unusedRefunded,
    required this.feeFailed,
    required this.insufficient,
    required this.blocked,
  });

  final List<SwapRow> rows;

  /// Whether the payment holds the slippage allowance, what the swap does not
  /// use of it being refunded: an exact output's.
  final bool unusedRefunded;

  /// Whether the deposit's chain fee could not be had, and is to be asked for
  /// again.
  final bool feeFailed;

  /// Whether the account cannot cover the payment with its chain fee.
  final bool insufficient;

  /// Whether the swap cannot be confirmed as things stand.
  final bool blocked;
}

/// The review of [quote]. Where the app sends the deposit itself, as for a
/// swap out of QTC, [fee] is its chain fee as far as it is known and
/// [spendable] what the account can spend, once known; both are null where
/// the deposit is made by hand. Nothing can be confirmed where swaps are not
/// [available], or while the app's own deposit cannot be told to be covered.
SwapReview swapReviewOf(
  AppLocalizations l10n,
  NumberFormattingService fmt,
  SwapQuote quote, {
  required bool available,
  required AsyncValue<BigInt>? fee,
  required BigInt? spendable,
}) {
  final from = quote.fromToken;
  final to = quote.toToken;
  final swapOut = from.isQuantus;
  final quantus = swapOut ? from : to;
  final foreign = swapOut ? to : from;
  final exactOutput = quote.swapType == SwapType.exactOutput;
  final sendsDeposit = fee != null;
  final feeValue = fee?.value;
  final insufficient = feeValue != null && spendable != null && quote.amountIn > swapMaxIn(spendable, feeValue);
  String amount(BigInt value, SwapToken token) => formatSwapAmount(l10n, fmt, value, token);

  return SwapReview(
    rows: [
      SwapRowText(
        l10n.swapRate,
        l10n.swapRateLabel(
          quantus.symbol,
          fmt.formatAmount(swapQuoteRate(quote), decimals: foreign.decimals),
          foreign.symbol,
        ),
      ),
      ...swapQuoteFeeRowsOf(l10n, fmt, quote),
      if (swapOut)
        SwapRowAddress(l10n.swapReviewRecipient, quote.recipient)
      else
        SwapRowAddress(l10n.swapRefundTo, quote.refundAddress),
      if (fee != null)
        SwapRowText(
          l10n.swapReviewNetworkFee,
          fee.hasError ? l10n.swapReviewFeeUnavailable : (feeValue == null ? '…' : amount(feeValue, from)),
        ),
      SwapRowText(
        l10n.swapReviewSlippage,
        l10n.swapReviewSlippageValue(
          exactOutput
              ? amount(quote.amountIn - quote.minAmountIn, from)
              : amount(quote.amountOut - quote.minAmountOut, to),
          slippagePercentLabel(quote.slippageBps),
        ),
      ),
      SwapRowText(l10n.swapReviewGuaranteedMinimum, amount(quote.minAmountOut, to)),
      if (quote.refundFee > BigInt.zero) SwapRowText(l10n.swapReviewRefundFee, amount(quote.refundFee, from)),
    ],
    unusedRefunded: exactOutput,
    feeFailed: fee != null && fee.hasError,
    insufficient: insufficient,
    blocked: !available || sendsDeposit && (feeValue == null || spendable == null || insufficient),
  );
}
