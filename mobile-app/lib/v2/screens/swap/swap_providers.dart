import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/swap_preflight.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';

/// The stand-in for QTC this build was started with; null in every real build.
final swapPreflightProvider = Provider<SwapPreflight?>((_) => SwapPreflight.fromEnvironment);

/// Debug builds only: a stand-in for 1Click the swap test harness puts in
/// place, so every swap screen can be walked without the network; null in
/// real use.
final swapHarnessServiceProvider = StateProvider<SwapService?>((_) => null);

final swapServiceProvider = Provider<SwapService>((ref) {
  final harness = ref.watch(swapHarnessServiceProvider);
  if (harness != null) return harness;
  final preflight = ref.watch(swapPreflightProvider);
  if (preflight != null) return SwapService(quantusAssetId: preflight.assetId, preflight: true);
  return SwapService(quantusAssetId: ref.watch(remoteConfigProvider.select((c) => c.swapQuantusAssetId)));
});

final swapTokenIconServiceProvider = Provider<SwapTokenIconService>((ref) => SwapTokenIconService());

/// [token]'s logo; null while it loads, when there is none, or when the fetch
/// failed (logged, retried on the next build).
final swapTokenIconProvider = FutureProvider.autoDispose.family<SwapTokenIcon?, SwapToken>((ref, token) async {
  try {
    return await ref.watch(swapTokenIconServiceProvider).iconFor(token);
  } catch (e) {
    quantusPrint('Logo for ${token.symbol} failed: $e');
    return null;
  }
});

/// The image at a URL, such as a chain's logo; null while it loads or when
/// the fetch failed (logged, retried on the next build).
final swapImageProvider = FutureProvider.autoDispose.family<SwapTokenIcon?, String>((ref, url) async {
  try {
    return await ref.watch(swapTokenIconServiceProvider).imageAt(url);
  } catch (e) {
    quantusPrint('Image $url failed: $e');
    return null;
  }
});

/// Slippage tolerances offered for a quote, in basis points.
const swapSlippageOptionsBps = [50, 100, 200];

/// Highest custom slippage tolerance, in basis points.
const swapSlippageMaxBps = 9900;

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

/// The most QTC a balance of [spendable] can put into a swap: the deposit's
/// chain [fee] stays behind, and the existential deposit that keeps the
/// account alive.
BigInt swapMaxIn(BigInt spendable, BigInt fee) {
  final max = spendable - fee - balances.Constants().existentialDeposit;
  return max > BigInt.zero ? max : BigInt.zero;
}

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

/// Base units of [quote]'s foreign token that one whole QTC buys or sells
/// for before the fees: the swap trades the input it needs less the
/// percentage fee, for the payout plus its withdrawal fee. An exact output's
/// payment holds a buffer on top.
BigInt swapQuoteRate(SwapQuote quote) {
  final swapOut = quote.fromToken.isQuantus;
  final unit = BigInt.from(10).pow((swapOut ? quote.fromToken : quote.toToken).decimals);
  final traded = quote.minAmountIn - quote.feeAmount;
  final bought = quote.amountOut + quote.withdrawFee;
  return swapOut ? bought * unit ~/ traded : traded * unit ~/ bought;
}

/// A swap as the form describes it; equal requests share one quote.
typedef SwapQuoteRequest = ({
  SwapToken from,
  SwapToken to,
  BigInt amount,
  SwapType swapType,
  String refundAddress,
  String recipient,
  int slippageBps,
});

/// How long the form waits after its last change before it asks for a quote.
const swapFormQuoteDebounce = Duration(milliseconds: 300);

/// How long a quote stays on the form before a fresh one replaces it.
const swapFormQuoteLifetime = Duration(seconds: 20);

/// 1Click's dry quote for the swap the form describes, asked for once the
/// form has rested for [swapFormQuoteDebounce] and again every
/// [swapFormQuoteLifetime] for as long as the form shows it.
final swapFormQuoteProvider = FutureProvider.autoDispose.family<SwapQuote, SwapQuoteRequest>((ref, request) async {
  final service = ref.watch(swapServiceProvider);
  final rested = Completer<void>();
  final debounce = Timer(swapFormQuoteDebounce, rested.complete);
  ref.onDispose(debounce.cancel);
  await rested.future;
  try {
    return await service.getQuote(
      from: request.from,
      to: request.to,
      amount: request.amount,
      swapType: request.swapType,
      refundAddress: request.refundAddress,
      recipient: request.recipient,
      slippageBps: request.slippageBps,
    );
  } catch (e) {
    quantusPrint('Swap quote failed: $e');
    rethrow;
  } finally {
    if (ref.mounted) {
      final refresh = Timer(swapFormQuoteLifetime, ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
    }
  }
}, retry: (_, _) => null);

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

String describeSwapError(AppLocalizations l10n, Object error) => switch (error) {
  SwapApiException e => e.message,
  TimeoutException _ => l10n.swapRequestTimedOut,
  _ => error.toString(),
};

String slippagePercentLabel(int bps) {
  final percent = bps / 100;
  return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toString();
}
