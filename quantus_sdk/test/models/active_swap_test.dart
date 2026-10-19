import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../fixtures/active_swap_fixture.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  final deadline = now.add(const Duration(minutes: 20));
  ActiveSwap swap(SwapStatus status) => activeSwapIn(status, startedAt: now, deadline: deadline);

  test('survives a JSON round trip with its quote, tokens and status', () {
    final kept = ActiveSwap.fromJson(jsonDecode(jsonEncode(swap(SwapStatus.processing).toJson())));

    expect(kept.order.status, SwapStatus.processing);
    expect(kept.order.amountOut, BigInt.from(24900000));
    expect(kept.order.refundedAmount, BigInt.one);
    expect(kept.order.refundReason, 'No liquidity');
    expect(kept.order.originTxHashes, ['0xorigin']);
    expect(kept.order.destinationTxHashes, ['0xdest']);
    final quote = kept.order.quote;
    expect(quote.fromToken, qtc);
    expect(quote.fromToken.isQuantus, isTrue);
    expect(quote.toToken.networkImageUrl, usdcEth.networkImageUrl);
    expect(quote.toToken.marketCapUsd, usdcEth.marketCapUsd);
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

  test('a swap is overdue once its deposit is unseen at the deadline, or unsettled an hour past it', () {
    final past = deadline.add(const Duration(seconds: 1));
    final late = deadline.add(ActiveSwap.finishGrace).add(const Duration(seconds: 1));
    expect(swap(SwapStatus.pendingDeposit).overdue(past), isTrue);
    expect(swap(SwapStatus.pendingDeposit).overdue(deadline.subtract(const Duration(seconds: 1))), isFalse);
    expect(swap(SwapStatus.knownDepositTx).overdue(past), isFalse);
    expect(swap(SwapStatus.processing).overdue(late), isTrue);
    expect(swap(SwapStatus.success).overdue(late), isFalse);
    expect(swap(SwapStatus.processing).inProgressAt(past), isTrue);
    expect(swap(SwapStatus.processing).inProgressAt(late), isFalse);
  });
}
