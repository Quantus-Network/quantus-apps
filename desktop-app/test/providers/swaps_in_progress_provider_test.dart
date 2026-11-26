import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/swaps_in_progress_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

void main() {
  /// Follows [swaps], kept on the device, with [oneClick] answering for
  /// them. The test disposes of it, so that no timer of its outlives it.
  ProviderContainer following(List<ActiveSwap> swaps, FakeSwapService oneClick) {
    return ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService()..activeSwaps = swaps),
        swapServiceProvider.overrideWithValue(oneClick),
        keepsUnpaidSwapsProvider.overrideWithValue(true),
      ],
    );
  }

  List<String> ids(List<ActiveSwap> swaps) => [for (final swap in swaps) swap.order.depositAddress];

  testWidgets('a swap in progress counts, not one ended, awaiting its deposit by hand, or overdue', (tester) async {
    final container = following([
      fakeActiveSwap(depositAddress: '0xrunning'),
      fakeActiveSwap(depositAddress: '0xshort', status: SwapStatus.incompleteDeposit),
      fakeActiveSwap(depositAddress: '0xswapped', status: SwapStatus.success),
      fakeActiveSwap(depositAddress: '0xrefunded', status: SwapStatus.refunded),
      fakeActiveSwap(depositAddress: '0xfailed', status: SwapStatus.failed),
      fakeActiveSwap(depositAddress: '0xawaited', swapOut: false, status: SwapStatus.pendingDeposit),
      fakeActiveSwap(
        depositAddress: '0xoverdue',
        deadline: clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
      ),
    ], FakeSwapService()..status = (_) => Completer<SwapOrder>().future);

    expect(ids(container.read(swapsInProgressProvider)), ['0xrunning', '0xshort']);
    container.dispose();
  });

  testWidgets('a swap that turns overdue leaves at that moment, with no answer from 1Click', (tester) async {
    final turnsOverdue = clock.now().add(const Duration(minutes: 1));
    final container = following([
      fakeActiveSwap(depositAddress: '0xturning', deadline: turnsOverdue.subtract(ActiveSwap.finishGrace)),
    ], FakeSwapService()..status = (_) => Completer<SwapOrder>().future);
    final seen = <List<String>>[];
    container.listen(swapsInProgressProvider, (_, swaps) => seen.add(ids(swaps)), fireImmediately: true);

    await tester.pump(const Duration(seconds: 59));
    expect(seen, [
      ['0xturning'],
    ]);

    await tester.pump(const Duration(seconds: 2));
    expect(seen.last, isEmpty);
    container.dispose();
  });
}
