import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/app_lifecycle_state_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

const _usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
const _qtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);

/// A swap into QTC whose deposit goes to [depositAddress] by hand, its window
/// still open: awaited until [sent], then under way.
ActiveSwap _swapIn(String depositAddress, {required bool sent}) => ActiveSwap(
  order: SwapOrder(
    quote: SwapQuote(
      fromToken: _usdc,
      toToken: _qtc,
      amountIn: BigInt.from(25000000),
      minAmountIn: BigInt.from(25000000),
      amountOut: BigInt.from(248),
      minAmountOut: BigInt.from(245),
      amountInUsd: 25,
      amountOutUsd: 24.8,
      slippageBps: 100,
      refundAddress: '0xrefund',
      recipient: 'qzaccount',
      deadline: clock.now().add(const Duration(minutes: 20)),
      timeEstimate: const Duration(minutes: 1),
      correlationId: 'c',
      signature: 's',
      depositAddress: depositAddress,
    ),
    status: SwapStatus.pendingDeposit,
  ),
  accountId: 'qzaccount',
  accountName: 'Main',
  startedAt: clock.now(),
  depositByHand: true,
  depositSent: sent,
);

/// A swap out of QTC the app sent the deposit of to [depositAddress], with
/// 1Click: still within its time, or [overdue], ten minutes and more past
/// its deadline with nothing settled, or overdue once [overdueIn] has passed.
ActiveSwap _swapOut(String depositAddress, {required bool overdue, Duration? overdueIn}) {
  final deadline = overdueIn != null
      ? clock.now().subtract(ActiveSwap.finishGrace).add(overdueIn)
      : overdue
      ? clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1))
      : clock.now().add(const Duration(minutes: 20));
  return ActiveSwap(
    order: SwapOrder(
      quote: SwapQuote(
        fromToken: _qtc,
        toToken: _usdc,
        amountIn: BigInt.from(250),
        minAmountIn: BigInt.from(250),
        amountOut: BigInt.from(25000000),
        minAmountOut: BigInt.from(24700000),
        amountInUsd: 25,
        amountOutUsd: 24.8,
        slippageBps: 100,
        refundAddress: 'qzaccount',
        recipient: '0xrecipient',
        deadline: deadline,
        timeEstimate: const Duration(minutes: 1),
        correlationId: 'c',
        signature: 's',
        depositAddress: depositAddress,
      ),
      status: SwapStatus.processing,
    ),
    accountId: 'qzaccount',
    accountName: 'Main',
    startedAt: deadline.subtract(const Duration(minutes: 20)),
    depositByHand: false,
    depositTxHash: '0xhash',
  );
}

/// 1Click, answering each status asked for with the order as it is, and
/// keeping the deposit addresses asked about, in order.
class _OneClick extends Fake implements SwapService {
  final polled = <String>[];

  /// While set, the status of the swap at this deposit address waits for
  /// [release].
  String? held;
  final release = Completer<void>();

  @override
  Future<SwapOrder> getSwapStatus(SwapOrder order) async {
    polled.add(order.depositAddress);
    if (order.depositAddress == held) await release.future;
    return order;
  }
}

void main() {
  group('polling, with an overdue swap followed beside a running one', () {
    late _OneClick oneClick;
    late ProviderContainer container;

    /// Launches following [swaps], an overdue swap at 0xold and a running
    /// one at 0xnow unless said, and lets the launch's poll end.
    Future<void> launch(WidgetTester tester, {List<ActiveSwap>? swaps}) async {
      oneClick = _OneClick();
      container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(
            FakeSettingsService()
              ..activeSwaps.addAll(swaps ?? [_swapOut('0xold', overdue: true), _swapOut('0xnow', overdue: false)]),
          ),
          swapServiceProvider.overrideWithValue(oneClick),
        ],
      );
      container.read(activeSwapsProvider);
      await tester.pump(Duration.zero);
    }

    /// Ends the container inside the test, so no timer of its is still
    /// waiting when the test ends.
    Future<void> close(WidgetTester tester) async {
      container.dispose();
      await tester.pump(const Duration(minutes: 1));
    }

    Future<void> interval(WidgetTester tester) => tester.pump(SwapService.statusPollInterval);

    testWidgets('the overdue swap is polled at launch, and then left out of every interval', (tester) async {
      await launch(tester);
      expect(oneClick.polled, ['0xold', '0xnow']);

      await interval(tester);
      await interval(tester);
      await interval(tester);

      expect(oneClick.polled, ['0xold', '0xnow', '0xnow', '0xnow', '0xnow']);
      await close(tester);
    });

    testWidgets('a swap that turns overdue between intervals is polled on the one already begun, and on none after', (
      tester,
    ) async {
      await launch(
        tester,
        swaps: [
          _swapOut('0xturning', overdue: false, overdueIn: SwapService.statusPollInterval * 1.5),
          _swapOut('0xnow', overdue: false),
        ],
      );
      expect(oneClick.polled, isEmpty, reason: 'nothing is overdue at launch');

      await interval(tester);
      expect(oneClick.polled, ['0xturning', '0xnow']);

      // It turned overdue half an interval ago: what settled just before is
      // still learned of.
      await interval(tester);
      expect(oneClick.polled, ['0xturning', '0xnow', '0xturning', '0xnow']);

      await interval(tester);
      await interval(tester);
      expect(oneClick.polled, ['0xturning', '0xnow', '0xturning', '0xnow', '0xnow', '0xnow']);
      await close(tester);
    });

    testWidgets('a return to the foreground polls the overdue swap once more', (tester) async {
      await launch(tester);
      await interval(tester);
      oneClick.polled.clear();

      container.read(appLifecycleStateProvider.notifier).state = AppLifecycleState.paused;
      container.read(appLifecycleStateProvider.notifier).state = AppLifecycleState.resumed;
      await tester.pump();
      expect(oneClick.polled, ['0xold', '0xnow']);

      await interval(tester);
      expect(oneClick.polled, ['0xold', '0xnow', '0xnow']);
      await close(tester);
    });

    testWidgets('a refresh asked for polls the overdue swap too', (tester) async {
      await launch(tester);
      await interval(tester);
      oneClick.polled.clear();

      await container.read(activeSwapsProvider.notifier).refresh();

      expect(oneClick.polled, ['0xold', '0xnow']);
      await close(tester);
    });

    testWidgets("a refresh asked for while an interval's poll is out polls the overdue swap once that poll ends", (
      tester,
    ) async {
      await launch(tester);
      oneClick.polled.clear();
      oneClick.held = '0xnow';
      await interval(tester);
      expect(oneClick.polled, ['0xnow'], reason: "the interval's poll is out");

      final refreshed = container.read(activeSwapsProvider.notifier).refresh();
      final again = container.read(activeSwapsProvider.notifier).refresh();
      await tester.pump();
      expect(oneClick.polled, ['0xnow'], reason: 'nothing more goes out while it is');

      oneClick.held = null;
      oneClick.release.complete();
      await refreshed;
      await again;

      expect(oneClick.polled, ['0xnow', '0xold'], reason: 'asked for twice, the overdue swap is polled once');
      await close(tester);
    });
  });

  late FakeSettingsService settings;

  setUp(() {
    settings = FakeSettingsService()
      ..activeSwaps.addAll([_swapIn('0xunpaid', sent: false), _swapIn('0xsent', sent: true)]);
  });

  ProviderContainer launch({bool? keepsUnpaid}) {
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(settings),
        if (keepsUnpaid != null) keepsUnpaidSwapsProvider.overrideWithValue(keepsUnpaid),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  List<String> ids(Iterable<ActiveSwap> swaps) => [for (final swap in swaps) swap.id];

  test('a swap still awaiting its deposit by hand is dropped at launch, from the device too', () async {
    final container = launch();

    expect(ids(container.read(activeSwapsProvider)), ['0xsent']);
    await Future<void>.delayed(Duration.zero);
    expect(ids(settings.activeSwaps), ['0xsent']);
  });

  test('where the app keeps unpaid swaps, one awaiting its deposit is still followed after launch', () async {
    final container = launch(keepsUnpaid: true);

    expect(ids(container.read(activeSwapsProvider)), ['0xunpaid', '0xsent']);
    await Future<void>.delayed(Duration.zero);
    expect(ids(settings.activeSwaps), ['0xunpaid', '0xsent']);
  });
}
