import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';

final swapServiceProvider = Provider<SwapService>((_) => SwapService());

/// Slippage tolerances offered for a quote, in basis points.
const swapSlippageOptionsBps = [50, 100, 200, 300];

/// Slippage tolerance the next quote asks for, in basis points.
final swapSlippageBpsProvider = StateProvider<int>((_) => SwapService.defaultSlippageBps);

/// QTC as a swap token, priced with the same rate the rest of the app uses.
final quantusSwapTokenProvider = Provider<SwapToken>(
  (ref) => SwapService.quantusToken(usdPrice: ref.watch(exchangeRateServiceProvider).tokenToUsdRate.toDouble()),
);

/// Chain fee for sending [amount] QTC from the account into a deposit address.
/// The recipient barely moves the fee, so the account's own address stands in
/// until the live quote names the deposit address.
final swapDepositFeeProvider = FutureProvider.autoDispose.family<BigInt, (Account, BigInt)>((ref, args) async {
  final (account, amount) = args;
  try {
    return (await RegularSendStrategy(
      account: account,
    ).fetchFee(ref.read, recipient: account.accountId, amount: amount)).networkFee;
  } catch (e) {
    quantusPrint('Swap deposit fee failed: $e');
    rethrow;
  }
}, retry: (_, _) => null);

/// [order] followed through 1Click's status endpoint until it settles.
final swapOrderProvider = StreamProvider.autoDispose.family<SwapOrder, SwapOrder>((ref, order) async* {
  final service = ref.watch(swapServiceProvider);
  var current = order;
  yield current;
  while (!current.status.isFinal) {
    await Future<void>.delayed(SwapService.statusPollInterval);
    if (!ref.mounted) return;
    try {
      current = await service.getSwapStatus(current);
      yield current;
    } catch (e) {
      quantusPrint('Swap status poll failed: $e');
    }
  }
});

/// USD value of [amount] base units of [token] at its listed price.
double swapUsdValue(BigInt amount, SwapToken token) => amount.toDouble() / pow(10, token.decimals) * token.usdPrice;

/// Base units of [to] that [amountIn] of [from] is worth at listed prices.
BigInt swapEstimateOut(BigInt amountIn, SwapToken from, SwapToken to) {
  if (to.usdPrice <= 0) return BigInt.zero;
  return BigInt.from(swapUsdValue(amountIn, from) / to.usdPrice * pow(10, to.decimals));
}

/// Base units of [quote]'s output token that one whole input token buys.
BigInt swapQuoteRate(SwapQuote quote) =>
    quote.amountOut * BigInt.from(10).pow(quote.fromToken.decimals) ~/ quote.amountIn;

/// [value] base units of [token] with its symbol, e.g. "24.86 USDC".
String formatSwapAmount(AppLocalizations l10n, NumberFormattingService fmt, BigInt value, SwapToken token) =>
    l10n.commonAmountBalance(fmt.formatAmount(value, decimals: token.decimals), token.symbol);

String describeSwapError(Object error) => error is SwapApiException ? error.message : error.toString();

String slippagePercentLabel(int bps) {
  final percent = bps / 100;
  return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toString();
}
