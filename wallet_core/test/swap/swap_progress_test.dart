import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/swap/swap_progress.dart';

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

  group('the view a followed swap shows', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final fmt = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
    final now = DateTime.utc(2026, 10, 15, 12);
    final unit = BigInt.from(10).pow(AppConstants.decimals);
    const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
    const qtc = SwapToken(
      assetId: 'nep141:qtc.omft.near',
      symbol: 'QTC',
      network: SwapToken.quantusNetwork,
      decimals: AppConstants.decimals,
      usdPrice: 0.1,
      isQuantus: true,
    );

    /// A live quote for 250 QTC out, or 25 USDC in, due [deadline].
    SwapQuote quote({required bool swapOut, DateTime? deadline}) => SwapQuote(
      fromToken: swapOut ? qtc : usdc,
      toToken: swapOut ? usdc : qtc,
      amountIn: swapOut ? unit * BigInt.from(250) : BigInt.from(25000000),
      minAmountIn: swapOut ? unit * BigInt.from(250) : BigInt.from(25000000),
      amountOut: swapOut ? BigInt.from(24860000) : unit * BigInt.from(248),
      minAmountOut: swapOut ? BigInt.from(24611400) : unit * BigInt.from(245),
      amountInUsd: 25,
      amountOutUsd: 24.86,
      slippageBps: 100,
      refundAddress: swapOut ? 'qzaccount' : '0xrefund',
      recipient: swapOut ? '0xrecipient' : 'qzaccount',
      deadline: deadline ?? now.add(const Duration(minutes: 20)),
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'c',
      signature: 's',
      depositAddress: 'qzdeposit',
    );

    /// The swap as followed: the app sent a swap out's deposit, a swap in
    /// waits for one made by hand.
    ActiveSwap swap(SwapOrder order) {
      final swapOut = order.quote.fromToken.isQuantus;
      return ActiveSwap(
        order: order,
        accountId: 'qzaccount',
        accountName: 'Savings',
        startedAt: now.subtract(const Duration(minutes: 1)),
        depositByHand: !swapOut,
        depositTxHash: swapOut ? '0xtxhash' : null,
      );
    }

    SwapFailure failure(ActiveSwap swap, {bool expired = false, bool preflight = false}) =>
        swapFailureOf(l10n, fmt, swap, expired: expired, preflight: preflight, addressLabel: (address) => '<$address>');

    test('each status has its view; a deposit by hand is awaited until sent, and expired past its deadline', () {
      SwapProgressView view(SwapOrder order, {bool sent = false, DateTime? at}) =>
          swapProgressViewOf(sent ? swap(order).withDepositSent() : swap(order), at ?? now);
      final out = quote(swapOut: true);
      final into = quote(swapOut: false);
      SwapOrder order(SwapQuote quote, SwapStatus status) => SwapOrder(quote: quote, status: status);

      expect(view(order(out, SwapStatus.success)), SwapProgressView.complete);
      for (final status in [SwapStatus.refunded, SwapStatus.failed, SwapStatus.incompleteDeposit]) {
        expect(view(order(out, status)), SwapProgressView.failed, reason: '$status');
      }
      for (final status in [SwapStatus.knownDepositTx, SwapStatus.processing]) {
        expect(view(order(into, status)), SwapProgressView.inProgress, reason: '$status');
      }

      // Sent by the app: on its way, however late.
      expect(view(order(out, SwapStatus.pendingDeposit)), SwapProgressView.inProgress);
      final late = now.add(const Duration(hours: 1));
      expect(view(order(out, SwapStatus.pendingDeposit), at: late), SwapProgressView.inProgress);

      // To be made by hand: awaited, then expired; once marked sent, on its way.
      expect(view(order(into, SwapStatus.pendingDeposit)), SwapProgressView.deposit);
      expect(view(order(into, SwapStatus.pendingDeposit), at: late), SwapProgressView.expired);
      expect(view(order(into, SwapStatus.pendingDeposit), sent: true), SwapProgressView.inProgress);
      expect(view(order(into, SwapStatus.pendingDeposit), sent: true, at: late), SwapProgressView.inProgress);
    });

    test('a deposit that never came is a caution: the quote expired', () {
      final ended = failure(
        swap(SwapOrder(quote: quote(swapOut: false), status: SwapStatus.pendingDeposit)),
        expired: true,
      );
      expect(ended.title, l10n.swapDepositExpiredTitle);
      expect(ended.message, l10n.swapDepositExpiredBody);
      expect(ended.isWarning, isTrue);
      expect(ended.refunded, isFalse);
    });

    test('too small a deposit is a caution of its own', () {
      final ended = failure(swap(SwapOrder(quote: quote(swapOut: false), status: SwapStatus.incompleteDeposit)));
      expect(ended.title, l10n.swapDepositIncompleteTitle);
      expect(ended.message, l10n.swapDepositIncompleteBody);
      expect(ended.isWarning, isTrue);
      expect(ended.refunded, isFalse);
    });

    test('a failure names the deposit address to quote to support', () {
      final ended = failure(swap(SwapOrder(quote: quote(swapOut: true), status: SwapStatus.failed)));
      expect(ended.title, l10n.swapFailedTitle);
      expect(ended.message, l10n.swapDepositFailedBody('qzdeposit'));
      expect(ended.isWarning, isFalse);
      expect(ended.refunded, isFalse);
    });

    test('a refund says what went back and where: the account, or the address outside it', () {
      final out = failure(swap(SwapOrder(quote: quote(swapOut: true), status: SwapStatus.refunded)));
      expect(out.title, l10n.swapFailedTitle);
      expect(out.message, l10n.swapRefundedBody('250 QTC', 'Savings', 'USDC'));
      expect(out.refunded, isTrue);
      expect(out.isWarning, isFalse);

      final into = failure(swap(SwapOrder(quote: quote(swapOut: false), status: SwapStatus.refunded)));
      expect(into.message, l10n.swapRefundedBody('25 USDC', '<0xrefund>', 'QTC'));

      // In preflight the stand-in is refunded at its own chain's address.
      final standIn = failure(
        swap(SwapOrder(quote: quote(swapOut: true), status: SwapStatus.refunded)),
        preflight: true,
      );
      expect(standIn.message, l10n.swapRefundedBody('250 QTC', '<qzaccount>', 'USDC'));
    });

    test('a refund gives the amount that came back when 1Click names it, and the reason when it has one', () {
      final ended = failure(
        swap(
          SwapOrder(
            quote: quote(swapOut: true),
            status: SwapStatus.refunded,
            refundedAmount: unit * BigInt.from(249),
            refundReason: 'PARTIAL_DEPOSIT',
          ),
        ),
      );
      expect(
        ended.message,
        '${l10n.swapRefundedBody('249 QTC', 'Savings', 'USDC')}\n\n${l10n.swapDepositRefundReason('PARTIAL_DEPOSIT')}',
      );
    });
  });
}
