import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/swap/swap_form.dart';

void main() {
  final fmt = NumberFormattingService(localeConfig: LocaleNumberConfig.dotDecimal);
  final unit = BigInt.from(10).pow(AppConstants.decimals);
  const usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
  const usdt = SwapToken(assetId: 'nep141:usdt.omft.near', symbol: 'USDT', network: 'ETH', decimals: 6, usdPrice: 1);
  const bonk = SwapToken(assetId: 'nep141:bonk.omft.near', symbol: 'BONK', network: 'SOL', decimals: 5, usdPrice: 1);
  const qtc = SwapToken(
    assetId: 'nep141:qtc.omft.near',
    symbol: 'QTC',
    network: SwapToken.quantusNetwork,
    decimals: AppConstants.decimals,
    usdPrice: 0.1,
    isQuantus: true,
  );

  group('the amount typed', () {
    test('is read in the units of the side it is typed on: what is paid, or what arrives', () {
      expect(swapTypedAmount(fmt, '10', from: qtc, to: usdc, exactOutput: false), unit * BigInt.from(10));
      expect(swapTypedAmount(fmt, '10', from: qtc, to: usdc, exactOutput: true), BigInt.from(10000000));
      expect(swapTypedAmount(fmt, '2.5', from: usdc, to: qtc, exactOutput: false), BigInt.from(2500000));
    });

    test('is nothing while it is empty or no number', () {
      expect(swapTypedAmount(fmt, '', from: qtc, to: usdc, exactOutput: false), BigInt.zero);
      expect(swapTypedAmount(fmt, 'abc', from: qtc, to: usdc, exactOutput: false), BigInt.zero);
    });
  });

  group('the swap the form asks a quote for', () {
    SwapQuoteRequest? request({
      bool swapOut = true,
      BigInt? typed,
      bool exactOutput = false,
      String? address = '0xoutside',
    }) => swapQuoteRequestOf(
      from: swapOut ? qtc : usdc,
      to: swapOut ? usdc : qtc,
      swapOut: swapOut,
      typed: typed ?? unit * BigInt.from(10),
      exactOutput: exactOutput,
      address: address,
      own: 'qzaccount',
      slippageBps: 100,
    );

    test('a swap out refunds to the account and pays the address given', () {
      expect(request(), (
        from: qtc,
        to: usdc,
        amount: unit * BigInt.from(10),
        swapType: SwapType.exactInput,
        refundAddress: 'qzaccount',
        recipient: '0xoutside',
        slippageBps: 100,
      ));
    });

    test('a swap in refunds to the address given and pays the account', () {
      final into = request(swapOut: false, typed: BigInt.from(25000000))!;
      expect(into.refundAddress, '0xoutside');
      expect(into.recipient, 'qzaccount');
      expect(into.from, usdc);
      expect(into.to, qtc);
    });

    test('typing what arrives asks for that exact amount out', () {
      expect(request(exactOutput: true)!.swapType, SwapType.exactOutput);
    });

    test('there is none until there is both an address and an amount', () {
      expect(request(address: null), isNull);
      expect(request(typed: BigInt.zero), isNull);
    });
  });

  group('the amounts the form shows', () {
    final quote = SwapQuote(
      fromToken: qtc,
      toToken: usdc,
      amountIn: unit * BigInt.from(10),
      minAmountIn: unit * BigInt.from(10),
      amountOut: BigInt.from(950000),
      minAmountOut: BigInt.from(940000),
      amountInUsd: 1,
      amountOutUsd: 0.95,
      slippageBps: 100,
      refundAddress: 'qzaccount',
      recipient: '0xoutside',
      deadline: DateTime.utc(2026, 10, 15, 12),
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'c',
      signature: 's',
    );

    test("are the quote's once there is one", () {
      final typed = unit * BigInt.from(10);
      expect(swapFormAmountsOf(typed: typed, from: qtc, to: usdc, exactOutput: false, quote: quote), (
        quote.amountIn,
        quote.amountOut,
      ));
    });

    test('until then the amount typed, and the other side at the listed prices', () {
      final typed = unit * BigInt.from(10);
      expect(swapFormAmountsOf(typed: typed, from: qtc, to: usdc, exactOutput: false, quote: null), (
        typed,
        swapEstimateOut(typed, qtc, usdc),
      ));
      // 10 QTC at $0.10 is one dollar of USDC.
      expect(swapEstimateOut(typed, qtc, usdc), BigInt.from(1000000));
    });

    test('typed on the receiving side, the payment is what is estimated', () {
      final typed = BigInt.from(1000000);
      expect(swapFormAmountsOf(typed: typed, from: qtc, to: usdc, exactOutput: true, quote: null), (
        swapEstimateOut(typed, usdc, qtc),
        typed,
      ));
      expect(swapEstimateOut(typed, usdc, qtc), unit * BigInt.from(10));
    });
  });

  group("the form's button", () {
    SwapFormAction action({BigInt? amountIn, BigInt? amountOut, BigInt? canPay, bool hasAddress = true}) =>
        swapFormActionOf(
          amountIn: amountIn ?? unit * BigInt.from(10),
          amountOut: amountOut ?? BigInt.from(1000000),
          canPay: canPay,
          hasAddress: hasAddress,
        );

    test('says the balance is short, and does nothing, when the account cannot pay the amount', () {
      final short = action(canPay: unit * BigInt.from(9));
      expect(short.step, SwapFormStep.insufficient);
      expect(short.isEnabled, isFalse);

      // The same before an address is given.
      expect(action(canPay: unit * BigInt.from(9), hasAddress: false).step, SwapFormStep.insufficient);
      expect(action(canPay: unit * BigInt.from(9), hasAddress: false).isEnabled, isFalse);
    });

    test('paying exactly what the account can pay is not short; nothing is checked when the other side pays', () {
      expect(action(canPay: unit * BigInt.from(10)).step, SwapFormStep.review);
      expect(action(canPay: null).step, SwapFormStep.review);
    });

    test('asks for the address first, even before any amount', () {
      final first = action(hasAddress: false, amountIn: BigInt.zero, amountOut: BigInt.zero);
      expect(first.step, SwapFormStep.addAddress);
      expect(first.isEnabled, isTrue);
    });

    test('then reviews, once both amounts are more than nothing', () {
      expect(action().step, SwapFormStep.review);
      expect(action().isEnabled, isTrue);
      expect(action(amountIn: BigInt.zero).isEnabled, isFalse);
      expect(action(amountOut: BigInt.zero).isEnabled, isFalse);
      expect(action(amountOut: BigInt.zero).step, SwapFormStep.review);
    });
  });

  group('picking a token', () {
    test('the one already there changes nothing', () {
      expect(swapTokenPickOf(tapped: usdc, picked: usdc, foreign: usdc), isNull);
      expect(swapTokenPickOf(tapped: qtc, picked: qtc, foreign: usdc), isNull);
    });

    test('another on the same network takes its place and keeps the address', () {
      final pick = swapTokenPickOf(tapped: usdc, picked: usdt, foreign: usdc)!;
      expect(pick.foreign, usdt);
      expect(pick.clearsAddress, isFalse);
      expect(pick.flips, isFalse);
    });

    test('one on another network clears the address: it was for the other chain', () {
      final pick = swapTokenPickOf(tapped: usdc, picked: bonk, foreign: usdc)!;
      expect(pick.foreign, bonk);
      expect(pick.clearsAddress, isTrue);
      expect(pick.flips, isFalse);
    });

    test("QTC picked for the other token's side moves QTC there: the direction flips, the token stays", () {
      final pick = swapTokenPickOf(tapped: usdc, picked: qtc, foreign: usdc)!;
      expect(pick.foreign, isNull);
      expect(pick.clearsAddress, isFalse);
      expect(pick.flips, isTrue);
    });

    test("another token picked for QTC's side takes the other side and flips the direction", () {
      final same = swapTokenPickOf(tapped: qtc, picked: usdt, foreign: usdc)!;
      expect(same.foreign, usdt);
      expect(same.clearsAddress, isFalse);
      expect(same.flips, isTrue);

      final elsewhere = swapTokenPickOf(tapped: qtc, picked: bonk, foreign: usdc)!;
      expect(elsewhere.clearsAddress, isTrue);
      expect(elsewhere.flips, isTrue);
    });
  });
}
