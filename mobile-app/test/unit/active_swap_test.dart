import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/active_swap.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';

const _usdc = SwapToken(
  assetId: 'nep141:usdc.omft.near',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
  imageUrl: 'https://img.test/usdc.png',
  networkImageUrl: 'https://img.test/eth.png',
  marketCapUsd: 1e9,
);
const _qtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);

SwapQuote _quote({required DateTime deadline}) => SwapQuote(
  fromToken: _qtc,
  toToken: _usdc,
  swapType: SwapType.exactOutput,
  amountIn: BigInt.from(250) * BigInt.from(10).pow(AppConstants.decimals),
  minAmountIn: BigInt.from(248) * BigInt.from(10).pow(AppConstants.decimals),
  amountOut: BigInt.from(24860000),
  minAmountOut: BigInt.from(24611400),
  amountInUsd: 25,
  amountOutUsd: 24.86,
  slippageBps: 100,
  refundAddress: 'qzrefund',
  recipient: '0xrecipient',
  deadline: deadline,
  timeEstimate: const Duration(seconds: 90),
  correlationId: 'corr',
  signature: 'ed25519:sig',
  depositAddress: 'qzdeposit',
  depositMemo: '4183920',
);

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  final deadline = now.add(const Duration(minutes: 20));

  ActiveSwap swap(SwapStatus status, {DateTime? startedAt, bool byHand = false}) => ActiveSwap(
    order: SwapOrder(
      quote: _quote(deadline: deadline),
      status: status,
      amountOut: BigInt.from(24900000),
      refundedAmount: BigInt.one,
      refundReason: 'No liquidity',
      originTxHashes: const ['0xorigin'],
      destinationTxHashes: const ['0xdest'],
    ),
    accountId: 'qzaccount',
    accountName: 'Account 1',
    startedAt: startedAt ?? now,
    depositByHand: byHand,
    depositTxHash: '0xtx',
    depositFee: BigInt.from(20000000000),
  );

  test('survives a JSON round trip with its quote, tokens and status', () {
    final kept = ActiveSwap.fromJson(jsonDecode(jsonEncode(swap(SwapStatus.processing).toJson())));

    expect(kept.order.status, SwapStatus.processing);
    expect(kept.order.amountOut, BigInt.from(24900000));
    expect(kept.order.refundedAmount, BigInt.one);
    expect(kept.order.refundReason, 'No liquidity');
    expect(kept.order.originTxHashes, ['0xorigin']);
    expect(kept.order.destinationTxHashes, ['0xdest']);
    final quote = kept.order.quote;
    expect(quote.fromToken, _qtc);
    expect(quote.fromToken.isQuantus, isTrue);
    expect(quote.toToken.networkImageUrl, _usdc.networkImageUrl);
    expect(quote.toToken.marketCapUsd, _usdc.marketCapUsd);
    expect(quote.swapType, SwapType.exactOutput);
    expect(quote.amountIn, BigInt.from(250) * BigInt.from(10).pow(AppConstants.decimals));
    expect(quote.minAmountIn, BigInt.from(248) * BigInt.from(10).pow(AppConstants.decimals));
    expect(quote.minAmountOut, BigInt.from(24611400));
    expect(quote.amountOutUsd, 24.86);
    expect(quote.slippageBps, 100);
    expect(quote.refundAddress, 'qzrefund');
    expect(quote.recipient, '0xrecipient');
    expect(quote.deadline.isAtSameMomentAs(deadline), isTrue);
    expect(quote.timeEstimate, const Duration(seconds: 90));
    expect(quote.correlationId, 'corr');
    expect(quote.signature, 'ed25519:sig');
    expect(quote.depositAddress, 'qzdeposit');
    expect(quote.depositMemo, '4183920');
    expect(kept.accountId, 'qzaccount');
    expect(kept.accountName, 'Account 1');
    expect(kept.startedAt.isAtSameMomentAs(now), isTrue);
    expect(kept.settledAt, isNull);
    expect(kept.depositByHand, isFalse);
    expect(kept.depositTxHash, '0xtx');
    expect(kept.depositFee, BigInt.from(20000000000));
  });

  test('a new status clears the last poll error and a final one stops the clock', () {
    final failing = swap(SwapStatus.pendingDeposit).withPollError('down');
    expect(failing.pollError, 'down');

    final processing = failing.withOrder(
      SwapOrder(quote: failing.order.quote, status: SwapStatus.processing),
      now: now.add(const Duration(minutes: 1)),
    );
    expect(processing.pollError, isNull);
    expect(processing.settledAt, isNull);
    expect(processing.elapsedAt(now.add(const Duration(minutes: 3))), const Duration(minutes: 3));

    final done = processing.withOrder(
      SwapOrder(quote: failing.order.quote, status: SwapStatus.success),
      now: now.add(const Duration(minutes: 2)),
    );
    expect(done.settledAt, now.add(const Duration(minutes: 2)));
    expect(done.elapsedAt(now.add(const Duration(hours: 1))), const Duration(minutes: 2));
    expect(ActiveSwap.fromJson(jsonDecode(jsonEncode(done.toJson()))).settledAt, done.settledAt);
  });

  test('is stale ten minutes in unless settled, and a pending deposit past its deadline is unseen', () {
    final late = now.add(const Duration(minutes: 10));
    expect(swap(SwapStatus.processing).isStale(late), isTrue);
    expect(swap(SwapStatus.processing).isStale(now.add(const Duration(minutes: 9))), isFalse);
    expect(swap(SwapStatus.success).isStale(late), isFalse);

    final past = deadline.add(const Duration(seconds: 1));
    expect(swap(SwapStatus.pendingDeposit).deadlinePassed(past), isTrue);
    expect(swap(SwapStatus.pendingDeposit).deadlinePassed(deadline.subtract(const Duration(seconds: 1))), isFalse);
    expect(swap(SwapStatus.knownDepositTx).deadlinePassed(past), isFalse);
  });

  test('each status maps to the step it is on', () {
    final pending = SwapOrder(
      quote: _quote(deadline: deadline),
      status: SwapStatus.pendingDeposit,
    );
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
        swapStage(SwapOrder(quote: pending.quote, status: status), depositByHand: false),
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
