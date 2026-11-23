import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/swap/swap_review.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final fmt = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
  final unit = BigInt.from(10).pow(AppConstants.decimals);
  final networkFee = unit ~/ BigInt.from(50);
  const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
  const qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1,
    isQuantus: true,
  );

  /// 250 QTC for 24.86 USDC, at least 24.6114; or 25 USDC for 248 QTC, at
  /// least 245.
  SwapQuote quote({
    bool swapOut = true,
    SwapType swapType = SwapType.exactInput,
    BigInt? minAmountIn,
    BigInt? withdrawFee,
    BigInt? refundFee,
    int feeBps = 0,
  }) {
    final amountIn = swapOut ? unit * BigInt.from(250) : BigInt.from(25000000);
    return SwapQuote(
      fromToken: swapOut ? qtc : usdc,
      toToken: swapOut ? usdc : qtc,
      swapType: swapType,
      amountIn: amountIn,
      minAmountIn: minAmountIn ?? amountIn,
      amountOut: swapOut ? BigInt.from(24860000) : unit * BigInt.from(248),
      minAmountOut: swapOut ? BigInt.from(24611400) : unit * BigInt.from(245),
      amountInUsd: 25,
      amountOutUsd: 24.86,
      slippageBps: 100,
      refundAddress: swapOut ? 'qzaccount' : '0xrefund',
      recipient: swapOut ? '0xrecipient' : 'qzaccount',
      deadline: DateTime.utc(2026, 10, 15, 12),
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'c',
      signature: 's',
      withdrawFee: withdrawFee,
      refundFee: refundFee,
      feeBps: feeBps,
    );
  }

  /// The review of [quote]. A swap out's deposit is the app's to send unless
  /// told otherwise: its fee is known and the balance covers it.
  SwapReview review(
    SwapQuote quote, {
    bool available = true,
    AsyncValue<BigInt>? fee,
    BigInt? spendable,
    bool sendsDeposit = true,
  }) {
    final sends = sendsDeposit && quote.fromToken.isQuantus;
    return swapReviewOf(
      l10n,
      fmt,
      quote,
      available: available,
      fee: sends ? fee ?? AsyncValue.data(networkFee) : null,
      spendable: sends ? spendable ?? unit * BigInt.from(1000) : null,
    );
  }

  String rate(SwapQuote quote) =>
      l10n.swapRateLabel('QTC', fmt.formatAmount(swapQuoteRate(quote), decimals: 6), 'USDC');

  test(
    'a swap out lists the rate, who is paid, the network fee, the slippage allowance and the least that arrives',
    () {
      final out = quote();

      expect(review(out).rows, [
        SwapRowText(l10n.swapRate, rate(out)),
        SwapRowAddress(l10n.swapReviewRecipient, '0xrecipient'),
        SwapRowText(l10n.swapReviewNetworkFee, '0.02 QTC'),
        SwapRowText(l10n.swapReviewSlippage, l10n.swapReviewSlippageValue('0.2486 USDC', '1')),
        SwapRowText(l10n.swapReviewGuaranteedMinimum, '24.6114 USDC'),
      ]);
      expect(review(out).unusedRefunded, isFalse);
      expect(review(out).feeFailed, isFalse);
    },
  );

  test('a swap in lists where a refund goes instead of who is paid, and no network fee: its deposit is not ours', () {
    final into = quote(swapOut: false);

    expect(review(into).rows, [
      SwapRowText(l10n.swapRate, rate(into)),
      SwapRowAddress(l10n.swapRefundTo, '0xrefund'),
      SwapRowText(l10n.swapReviewSlippage, l10n.swapReviewSlippageValue('3 QTC', '1')),
      SwapRowText(l10n.swapReviewGuaranteedMinimum, '245 QTC'),
    ]);
    expect(review(into).blocked, isFalse);
  });

  test('a swap out whose deposit is made by hand has no network fee either, and nothing of ours can block it', () {
    final byHand = review(quote(), sendsDeposit: false);

    expect(byHand.rows.whereType<SwapRowText>().map((row) => row.label), isNot(contains(l10n.swapReviewNetworkFee)));
    expect(byHand.rows.whereType<SwapRowAddress>().single, SwapRowAddress(l10n.swapReviewRecipient, '0xrecipient'));
    expect(byHand.blocked, isFalse);
  });

  test('the fees inside a quote follow the rate, each only when the quote carries it', () {
    expect(swapQuoteFeeRowsOf(l10n, fmt, quote()), isEmpty);

    final charged = quote(feeBps: 20, withdrawFee: BigInt.from(50000), refundFee: unit ~/ BigInt.from(10));
    final fees = [
      SwapRowText(l10n.swapReviewSwapFee, l10n.swapReviewSlippageValue('0.5 QTC', '0.2')),
      SwapRowText(l10n.swapReviewWithdrawalFee, '0.05 USDC'),
    ];
    expect(swapQuoteFeeRowsOf(l10n, fmt, charged), fees);
    expect(review(charged).rows, [
      SwapRowText(l10n.swapRate, rate(charged)),
      ...fees,
      SwapRowAddress(l10n.swapReviewRecipient, '0xrecipient'),
      SwapRowText(l10n.swapReviewNetworkFee, '0.02 QTC'),
      SwapRowText(l10n.swapReviewSlippage, l10n.swapReviewSlippageValue('0.2486 USDC', '1')),
      SwapRowText(l10n.swapReviewGuaranteedMinimum, '24.6114 USDC'),
      SwapRowText(l10n.swapReviewRefundFee, '0.1 QTC'),
    ]);

    final withdrawalOnly = swapQuoteFeeRowsOf(l10n, fmt, quote(withdrawFee: BigInt.from(50000)));
    expect(withdrawalOnly, [SwapRowText(l10n.swapReviewWithdrawalFee, '0.05 USDC')]);
  });

  test('an exact output holds its slippage allowance in the payment, and says what is unused comes back', () {
    final exact = quote(swapType: SwapType.exactOutput, minAmountIn: unit * BigInt.from(247));

    final terms = review(exact);
    expect(terms.rows, contains(SwapRowText(l10n.swapReviewSlippage, l10n.swapReviewSlippageValue('3 QTC', '1'))));
    expect(terms.unusedRefunded, isTrue);
  });

  test('a network fee still being asked for reads "…", one that could not be had "Unavailable", with a retry', () {
    SwapRowText feeRow(SwapReview review) =>
        review.rows.whereType<SwapRowText>().singleWhere((row) => row.label == l10n.swapReviewNetworkFee);

    final asking = review(quote(), fee: const AsyncValue.loading());
    expect(feeRow(asking).value, '…');
    expect(asking.feeFailed, isFalse);
    expect(asking.blocked, isTrue);

    final failed = review(quote(), fee: AsyncValue.error(StateError('chain down'), StackTrace.empty));
    expect(feeRow(failed).value, l10n.swapReviewFeeUnavailable);
    expect(failed.feeFailed, isTrue);
    expect(failed.blocked, isTrue);
  });

  test('a swap out is blocked until its fee and the balance are known and the balance covers both', () {
    final out = quote();
    final existential = swapMaxIn(unit * BigInt.from(1000), BigInt.zero);
    final keptBack = unit * BigInt.from(1000) - existential;
    final enough = out.amountIn + networkFee + keptBack;

    expect(review(out, spendable: enough).blocked, isFalse);
    expect(review(out, spendable: enough).insufficient, isFalse);

    final short = review(out, spendable: enough - BigInt.one);
    expect(short.insufficient, isTrue);
    expect(short.blocked, isTrue);

    // The balance not yet known: nothing to say is short, but nothing to send from either.
    final unknown = swapReviewOf(l10n, fmt, out, available: true, fee: AsyncValue.data(networkFee), spendable: null);
    expect(unknown.insufficient, isFalse);
    expect(unknown.blocked, isTrue);
  });

  test('where swaps are not allowed nothing can be confirmed, whichever way it goes', () {
    expect(review(quote(), available: false).blocked, isTrue);
    expect(review(quote(swapOut: false), available: false).blocked, isTrue);
  });
}
