import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

void main() {
  group("the Transaction panel's width", () {
    ({ProviderContainer container, FakeSettingsService settings, _RecordingTelemetry telemetry}) open({String? saved}) {
      final settings = FakeSettingsService();
      if (saved != null) settings.strings[InspectorWidthNotifier.settingsKey] = saved;
      final telemetry = _RecordingTelemetry();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWithValue(settings),
          telemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, settings: settings, telemetry: telemetry);
    }

    test('starts 380 wide and keeps within 360 and 480', () {
      final (:container, settings: _, telemetry: _) = open();
      final width = container.read(inspectorWidthProvider.notifier);

      expect(container.read(inspectorWidthProvider), 380);
      width.resizeTo(500);
      expect(container.read(inspectorWidthProvider), 480);
      width.resizeTo(300);
      expect(container.read(inspectorWidthProvider), 360);
    });

    test('is kept for the next start', () async {
      final (:container, :settings, telemetry: _) = open();

      container.read(inspectorWidthProvider.notifier).resizeTo(420);
      await container.read(inspectorWidthProvider.notifier).save();

      expect(settings.strings[InspectorWidthNotifier.settingsKey], '420.0');
      expect(open(saved: '420.0').container.read(inspectorWidthProvider), 420);
      expect(open(saved: '900').container.read(inspectorWidthProvider), 480);
    });

    test('saved unreadable, it starts at 380 and the stray value is reported', () {
      final (:container, settings: _, :telemetry) = open(saved: 'wide');

      expect(container.read(inspectorWidthProvider), 380);
      expect(telemetry.errors, ['The saved transaction panel width is unreadable']);
    });
  });

  testWidgets('the swap stays open while it is followed, and is no longer once it is put away', (tester) async {
    final container = ProviderContainer(
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..activeSwap = fakeActiveSwap(),
        balances: oneTokenEach,
      ),
    );
    container.listen(openedActivityViewProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 20));

    container.read(openedActivityProvider.notifier).open(const OpenedSwap());
    expect(container.read(openedActivityViewProvider), const OpenedSwap());

    await container.read(activeSwapsProvider.notifier).clearAll();
    expect(container.read(openedActivityViewProvider), isNull);

    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('with no swap, nothing of one is open', (tester) async {
    final container = ProviderContainer(
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );
    container.listen(openedActivityViewProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 20));

    container.read(openedActivityProvider.notifier).open(const OpenedSwap());
    expect(container.read(openedActivityViewProvider), isNull);

    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('rows are kept over a reload only for their own account: one still loading shows as loading', (
    tester,
  ) async {
    final chain = FakeSendChain()
      ..historyPages = [
        [
          TransferEvent(
            id: 'main-tx',
            from: 'qzMain',
            to: 'qzBob',
            amount: oneToken,
            timestamp: DateTime.now(),
            fee: FakeSendChain.usualFee,
            extrinsicHash: '0xmain-tx',
            blockNumber: 1,
            blockHash: '0xblock',
          ),
        ],
      ];
    final container = ProviderContainer(
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
        chain: chain,
      ),
    );
    container.listen(activityViewProvider, (_, _) {});
    for (var i = 0; i < 100 && container.read(activityViewProvider).value == null; i++) {
      await tester.pump();
    }
    expect(container.read(activityViewProvider).value?.settled.map((tx) => tx.id), ['main-tx']);

    chain.holdHistory = Completer<void>();
    await container.read(activeAccountProvider.notifier).setActiveAccount(const RegularAccount(savingsAccount));
    await tester.pump();

    final view = container.read(activityViewProvider);
    expect(view.isLoading, isTrue);
    expect(view.hasValue, isFalse, reason: "Main's rows are not Savings'");

    chain.holdHistory!.complete();
    await tester.pump();
    // Inside the test, so nothing it started is still waiting when it ends.
    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  });
}
