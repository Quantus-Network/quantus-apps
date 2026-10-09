import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/swap_preflight.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';

/// The stand-in for QTC this build was started with; null in every real build.
final swapPreflightProvider = Provider<SwapPreflight?>((_) => SwapPreflight.fromEnvironment);

final swapServiceProvider = Provider<SwapService>((ref) {
  final preflight = ref.watch(swapPreflightProvider);
  final apiKey = ref.watch(remoteConfigProvider.select((c) => c.nearPartnerJwt));
  if (preflight != null) return SwapService(quantusAssetId: preflight.assetId, preflight: true, apiKey: apiKey);
  return SwapService(
    quantusAssetId: ref.watch(remoteConfigProvider.select((c) => c.swapQuantusAssetId)),
    apiKey: apiKey,
  );
});

final swapTokenIconServiceProvider = Provider<SwapTokenIconService>((ref) => SwapTokenIconService());

/// [token]'s logo from its token contract on NEAR; null while it loads, when
/// there is none, or when the fetch failed (logged, retried on the next build).
final swapTokenIconProvider = FutureProvider.autoDispose.family<SwapTokenIcon?, SwapToken>((ref, token) async {
  try {
    return await ref.watch(swapTokenIconServiceProvider).iconFor(token);
  } catch (e) {
    quantusPrint('Logo for ${token.symbol} failed: $e');
    return null;
  }
});

/// Slippage tolerances offered for a quote, in basis points.
const swapSlippageOptionsBps = [50, 100, 200, 300];

/// Slippage tolerance the next quote asks for, in basis points.
final swapSlippageBpsProvider = StateProvider<int>((_) => SwapService.defaultSlippageBps);

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

/// Base units of [quote]'s output token that one whole input token buys.
BigInt swapQuoteRate(SwapQuote quote) =>
    quote.amountOut * BigInt.from(10).pow(quote.fromToken.decimals) ~/ quote.amountIn;

/// [value] base units of [token] with its symbol, e.g. "24.86 USDC". An
/// [exact] amount keeps every digit: what is sent must read as what is shown.
String formatSwapAmount(
  AppLocalizations l10n,
  NumberFormattingService fmt,
  BigInt value,
  SwapToken token, {
  bool exact = false,
}) => l10n.commonAmountBalance(
  exact ? fmt.formatExactAmount(value, decimals: token.decimals) : fmt.formatAmount(value, decimals: token.decimals),
  token.symbol,
);

String describeSwapError(Object error) => error is SwapApiException ? error.message : error.toString();

String slippagePercentLabel(int bps) {
  final percent = bps / 100;
  return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toString();
}
