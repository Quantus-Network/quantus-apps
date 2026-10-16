import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/swap_harness_tokens.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Debug builds only: 1Click as the swap test harness sees it, so every swap
/// screen can be walked without the network. Lists the tokens 1Click listed
/// when [oneClickTokensJson] was captured, with QTC priced, quotes at the
/// listed prices, reserves a made-up deposit address for a swap into QTC, and
/// walks each order through the statuses a real one passes, one step every
/// [pollsPerStep] polls, to success. A swap out of QTC is not confirmed: the
/// harness never sends real QTC anywhere.
class SwapHarnessService extends SwapService {
  static const usdc = SwapToken(
    assetId: 'nep141:eth-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.omft.near',
    symbol: 'USDC',
    network: 'ETH',
    decimals: 6,
    usdPrice: 1,
    imageUrl: 'https://coin-images.coingecko.com/coins/images/6319/large/usdc.png',
    networkImageUrl: 'https://coin-images.coingecko.com/coins/images/279/large/ethereum.png',
    marketCapUsd: 70e9,
  );
  static const qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1005,
    isQuantus: true,
  );

  /// An address on the foreign token's chain, and the deposit address a swap
  /// into QTC is given.
  static const externalAddress = '0xa5f3c2b1d4e8a7c9f2b5e6d7c8b9a0f1e2d3c7b9';
  static const externalDeposit = '0x6b2c9e4d1f8a3b5c7e9d0f2a4b6c8d0e1f3a5b7c';
  static const txHash = '0x9cbe7d1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c9e1f3a5b7c';

  static const pollsPerStep = 3;
  static const _steps = [
    SwapStatus.pendingDeposit,
    SwapStatus.knownDepositTx,
    SwapStatus.processing,
    SwapStatus.success,
  ];

  final _polls = <String, int>{};

  SwapHarnessService() : super(client: _HarnessClient(), feeBips: 0) {
    if (!kDebugMode) throw StateError('SwapHarnessService is for debug builds only');
  }

  /// A quote at the listed prices, with [slippageBps] of buffer on the side
  /// the price can move; live once it names a [depositAddress].
  static SwapQuote quoteFor({
    required SwapToken from,
    required SwapToken to,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    required DateTime deadline,
    SwapType swapType = SwapType.exactInput,
    int slippageBps = SwapService.defaultSlippageBps,
    String? depositAddress,
  }) {
    final exactOutput = swapType == SwapType.exactOutput;
    final amountIn = exactOutput ? swapEstimateOut(amount, to, from) : amount;
    final amountOut = exactOutput ? amount : swapEstimateOut(amount, from, to);
    final scale = BigInt.from(10000);
    final buffer = BigInt.from(slippageBps);
    return SwapQuote(
      fromToken: from,
      toToken: to,
      swapType: swapType,
      amountIn: exactOutput ? amountIn * (scale + buffer) ~/ scale : amountIn,
      minAmountIn: amountIn,
      amountOut: amountOut,
      minAmountOut: exactOutput ? amountOut : amountOut * (scale - buffer) ~/ scale,
      amountInUsd: swapUsdValue(amountIn, from),
      amountOutUsd: swapUsdValue(amountOut, to),
      slippageBps: slippageBps,
      refundAddress: refundAddress,
      recipient: recipient,
      deadline: deadline,
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'harness',
      signature: 'ed25519:harness',
      depositAddress: depositAddress,
    );
  }

  @override
  Future<List<SwapToken>> getFromTokens({bool forceRefresh = false}) async {
    final listed = await super.getFromTokens(forceRefresh: forceRefresh);
    return [qtc, ...listed.where((t) => !t.isQuantus)];
  }

  @override
  Future<SwapToken?> getListedQuantusToken({bool forceRefresh = false}) async => qtc;

  @override
  Future<SwapQuote> getQuote({
    required SwapToken from,
    required SwapToken to,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    SwapType swapType = SwapType.exactInput,
    int slippageBps = SwapService.defaultSlippageBps,
    bool dry = true,
  }) async {
    if (!dry) throw StateError('The harness quotes live through createSwap');
    return quoteFor(
      from: from,
      to: to,
      amount: amount,
      refundAddress: refundAddress,
      recipient: recipient,
      deadline: clock.now().add(SwapService.depositWindow),
      swapType: swapType,
      slippageBps: slippageBps,
    );
  }

  @override
  Future<SwapOrder> createSwap(SwapQuote quote) async {
    if (quote.fromToken.isQuantus) {
      throw const SwapApiException(0, 'The harness does not send QTC; open a swap out progress row instead');
    }
    final live = quoteFor(
      from: quote.fromToken,
      to: quote.toToken,
      amount: quote.swapType == SwapType.exactOutput ? quote.amountOut : quote.amountIn,
      refundAddress: quote.refundAddress,
      recipient: quote.recipient,
      deadline: clock.now().add(SwapService.depositWindow),
      swapType: quote.swapType,
      slippageBps: quote.slippageBps,
      depositAddress: externalDeposit,
    );
    return SwapOrder(quote: live, status: SwapStatus.pendingDeposit);
  }

  @override
  Future<void> submitDeposit(SwapOrder order, String txHash) async {}

  @override
  Future<SwapOrder> getSwapStatus(SwapOrder order) async {
    final polls = _polls.update(order.depositAddress, (n) => n + 1, ifAbsent: () => 1);
    final status = _steps[min(polls ~/ pollsPerStep, _steps.length - 1)];
    final done = status == SwapStatus.success;
    return SwapOrder(
      quote: order.quote,
      status: status,
      amountOut: done ? order.quote.amountOut : null,
      originTxHashes: status == SwapStatus.pendingDeposit ? const [] : const [txHash],
      destinationTxHashes: done ? const [txHash] : const [],
    );
  }
}

/// Answers 1Click's token listing from [oneClickTokensJson]; everything else,
/// as CoinGecko's logos and market caps, goes to the network.
class _HarnessClient extends http.BaseClient {
  final _network = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!request.url.path.endsWith('/v0/tokens')) return _network.send(request);
    return Future.value(
      http.StreamedResponse(
        Stream.value(utf8.encode(oneClickTokensJson)),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );
  }
}
