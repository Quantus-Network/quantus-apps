import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
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

void main() {
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
