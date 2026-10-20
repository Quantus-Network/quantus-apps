import 'package:quantus_sdk/src/models/swap_quote.dart';
import 'package:quantus_sdk/src/models/swap_token.dart';
import 'package:quantus_sdk/src/services/one_click_service.dart';

/// Slippage tolerances offered for a quote, in basis points.
const swapSlippageOptionsBps = [50, 100, 200, 300];

/// Highest custom slippage tolerance, in basis points.
const swapSlippageMaxBps = 9900;

/// One whole token of [decimals] in base units, as a double. An int `pow`
/// overflows past 18 decimals, and wNEAR has 24.
double _unit(int decimals) => BigInt.from(10).pow(decimals).toDouble();

/// USD value of [amount] base units of [token] at its listed price.
double swapUsdValue(BigInt amount, SwapToken token) => amount.toDouble() / _unit(token.decimals) * token.usdPrice;

/// Base units of [to] that [amountIn] of [from] is worth at listed prices.
BigInt swapEstimateOut(BigInt amountIn, SwapToken from, SwapToken to) {
  if (to.usdPrice <= 0) return BigInt.zero;
  return BigInt.from(swapUsdValue(amountIn, from) / to.usdPrice * _unit(to.decimals));
}

/// Base units of [quote]'s output token that one whole input token buys, at
/// the input the swap needs: an exact output's payment holds a buffer on top.
BigInt swapQuoteRate(SwapQuote quote) =>
    quote.amountOut * BigInt.from(10).pow(quote.fromToken.decimals) ~/ quote.minAmountIn;

String describeSwapError(Object error) => error is SwapApiException ? error.message : error.toString();

String slippagePercentLabel(int bps) {
  final percent = bps / 100;
  return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toString();
}
