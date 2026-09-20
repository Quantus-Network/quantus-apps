import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

final swapServiceProvider = Provider<SwapService>((_) => SwapService());

/// QTC as a swap destination, priced with the same rate the rest of the app uses.
final quantusSwapTokenProvider = Provider<SwapToken>(
  (ref) => SwapService.quantusToken(usdPrice: ref.watch(exchangeRateServiceProvider).tokenToUsdRate.toDouble()),
);

String describeSwapError(Object error) => error is SwapApiException ? error.message : error.toString();

String slippagePercentLabel(int bps) {
  final percent = bps / 100;
  return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toString();
}
