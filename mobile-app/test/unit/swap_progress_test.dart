import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';

void main() {
  test('each status maps to the step it is on', () {
    const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
    const qtc = SwapToken(
      assetId: 'nep141:qtc.omft.near',
      symbol: 'QTC',
      network: SwapToken.quantusNetwork,
      decimals: AppConstants.decimals,
      usdPrice: 0.1,
      isQuantus: true,
    );
    final quote = SwapQuote(
      fromToken: qtc,
      toToken: usdc,
      amountIn: BigInt.from(10).pow(AppConstants.decimals),
      minAmountIn: BigInt.from(10).pow(AppConstants.decimals),
      amountOut: BigInt.from(100000),
      minAmountOut: BigInt.from(99000),
      amountInUsd: 0.1,
      amountOutUsd: 0.1,
      slippageBps: 100,
      refundAddress: 'qzrefund',
      recipient: '0xrecipient',
      deadline: DateTime.utc(2026, 10, 15, 12),
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'c',
      signature: 's',
      depositAddress: 'qzdeposit',
    );
    final pending = SwapOrder(quote: quote, status: SwapStatus.pendingDeposit);
    expect(swapStage(pending, depositByHand: true), 0);
    expect(swapStage(pending, depositByHand: false), 1);
    for (final (status, stage) in [
      (SwapStatus.knownDepositTx, 1),
      (SwapStatus.incompleteDeposit, 1),
      (SwapStatus.processing, 2),
      (SwapStatus.refunded, 2),
      (SwapStatus.failed, 2),
      (SwapStatus.success, swapStepCount),
    ]) {
      expect(
        swapStage(SwapOrder(quote: quote, status: status), depositByHand: false),
        stage,
        reason: '$status',
      );
    }
  });

  test('the badge clock reads minutes and seconds, and hours once it gets there', () {
    expect(formatSwapElapsed(Duration.zero), '0:00');
    expect(formatSwapElapsed(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatSwapElapsed(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(formatSwapElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
}
