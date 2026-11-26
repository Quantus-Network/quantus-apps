import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/swap_harness_service.dart';

/// A swap of 25 USDC into QTC, as the swap form quotes it through the harness.
SwapQuote _swapIn() => SwapHarnessService.quoteFor(
  from: SwapHarnessService.usdc,
  to: SwapHarnessService.qtc,
  amount: BigInt.from(25000000),
  refundAddress: SwapHarnessService.externalAddress,
  recipient: 'qzMain',
  deadline: clock.now().add(SwapService.depositWindow),
);

void main() {
  test('each swap the harness creates has its own deposit address', () async {
    final harness = SwapHarnessService();

    final first = await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () => harness.createSwap(_swapIn()));
    final second = await withClock(Clock.fixed(DateTime(2026, 11, 25, 12, 0, 1)), () => harness.createSwap(_swapIn()));

    expect(first.depositAddress, startsWith(SwapHarnessService.externalDeposit));
    expect(second.depositAddress, startsWith(SwapHarnessService.externalDeposit));
    expect(second.depositAddress, isNot(first.depositAddress));
  });

  test('each swap walks its own steps: a second one starts where a swap starts', () async {
    final harness = SwapHarnessService();
    final first = await withClock(Clock.fixed(DateTime(2026, 11, 25, 12)), () => harness.createSwap(_swapIn()));
    final second = await withClock(Clock.fixed(DateTime(2026, 11, 25, 12, 0, 1)), () => harness.createSwap(_swapIn()));

    SwapOrder? polled;
    for (var i = 0; i < SwapHarnessService.pollsPerStep; i++) {
      polled = await harness.getSwapStatus(first);
    }
    expect(polled!.status, SwapStatus.knownDepositTx);

    expect((await harness.getSwapStatus(second)).status, SwapStatus.pendingDeposit);
  });
}
