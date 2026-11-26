import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/status_item_swaps.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/background_mode.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/app_locale.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';
import 'fake_background_window.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

/// A swap of 250 QTC out for 104.37 USDC, as the menu lists it.
const _swapOutLabel = '-250 QTC for 104.37 USDC on Arbitrum';
const _swapOutSteps = ['QTC sent', 'Confirming on Quantus', 'Swapping', 'Sending USDC to the recipient'];

/// A swap of 100 USDC in for 236.9 QTC, its deposit made by hand.
const _swapInLabel = '+236.9 QTC for 100 USDC on Arbitrum';

/// A swap into QTC whose deposit was made by hand, from [account].
ActiveSwap _swapIn({SwapStatus status = SwapStatus.knownDepositTx, Account account = mainAccount}) => fakeActiveSwap(
  swapOut: false,
  depositSent: true,
  status: status,
  account: account,
  depositAddress: '0x1111111111111111111111111111111111111111',
);

/// 1Click answering [status] for every swap asked about.
Future<SwapOrder> Function(SwapOrder) _answering(SwapStatus status) =>
    (order) async => SwapOrder(quote: order.quote, status: status);

typedef _Opened = ({ProviderContainer container, FakeBackgroundWindow window});

/// Opens Main's wallet following [swaps], with 1Click as [oneClick] answers.
Future<_Opened> _open(
  WidgetTester tester,
  List<ActiveSwap> swaps, {
  FakeSwapService? oneClick,
  List<Override> extra = const [],
}) async {
  final window = FakeBackgroundWindow();
  await pumpShell(
    tester,
    backgroundWindow: window,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..activeSwaps = swaps,
        swaps: oneClick,
      ),
      ...extra,
    ],
  );
  return (container: ProviderScope.containerOf(tester.element(find.byType(DesktopShell))), window: window);
}

Future<void> _interval(WidgetTester tester) => tester.pump(SwapService.statusPollInterval);

String? _activeAccountId(ProviderContainer container) => container.read(activeAccountProvider).value?.account.accountId;

void main() {
  group('the menu bar icon', () {
    testOnMac('is told no swaps and no title while none is in progress', (tester) async {
      final (:window, container: _) = await _open(tester, const []);

      expect(window.swaps.last, StatusItemSwaps.none);
    });

    testOnMac('does not list a swap that ended, came short, awaits its deposit by hand, or is overdue', (tester) async {
      final (:window, container: _) = await _open(tester, [
        fakeActiveSwap(status: SwapStatus.success),
        fakeActiveSwap(
          status: SwapStatus.incompleteDeposit,
          swapOut: false,
          depositSent: true,
          depositAddress: '0x2222222222222222222222222222222222222222',
        ),
        fakeActiveSwap(
          swapOut: false,
          status: SwapStatus.pendingDeposit,
          depositAddress: '0x3333333333333333333333333333333333333333',
        ),
        fakeActiveSwap(
          deadline: clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
          depositAddress: '0x4444444444444444444444444444444444444444',
        ),
      ]);

      expect(window.swaps.last, StatusItemSwaps.none);
    });

    testOnMac('shows a swap in progress from launch: Swap 2/4, what it is for, and its four steps', (tester) async {
      final swap = fakeActiveSwap();
      final (:window, container: _) = await _open(tester, [swap]);

      expect(
        window.swaps.last,
        StatusItemSwaps(
          title: 'Swap 2/4',
          swaps: [
            StatusItemSwap(
              swapId: swap.id,
              accountId: mainAccount.accountId,
              label: _swapOutLabel,
              steps: _swapOutSteps,
              current: 1,
            ),
          ],
        ),
      );
    });

    testOnMac('follows the swap: Swapping is Swap 3/4, on the third step', (tester) async {
      final oneClick = FakeSwapService();
      final (:window, container: _) = await _open(tester, [fakeActiveSwap()], oneClick: oneClick);

      oneClick.status = _answering(SwapStatus.processing);
      await _interval(tester);

      expect(window.swaps.last.title, 'Swap 3/4');
      expect(window.swaps.last.swaps.single.current, 2);
    });

    testOnMac('lets a swap go once it ends', (tester) async {
      final oneClick = FakeSwapService();
      final (:window, container: _) = await _open(tester, [fakeActiveSwap()], oneClick: oneClick);

      oneClick.status = _answering(SwapStatus.success);
      await _interval(tester);

      expect(window.swaps.last, StatusItemSwaps.none);
    });

    testOnMac('lets a swap go once it turns overdue, with no answer from 1Click', (tester) async {
      final (:window, container: _) = await _open(tester, [
        fakeActiveSwap(deadline: clock.now().add(const Duration(minutes: 1))),
      ]);
      expect(window.swaps.last.title, 'Swap 2/4');

      await tester.pump(const Duration(minutes: 1) + ActiveSwap.finishGrace + const Duration(seconds: 1));

      expect(window.swaps.last, StatusItemSwaps.none);
    });

    testOnMac('lists several swaps in the order they started, its title the newest with how many more', (tester) async {
      final out = fakeActiveSwap();
      final into = _swapIn(status: SwapStatus.processing, account: savingsAccount);
      final (:window, container: _) = await _open(tester, [out, into]);

      final told = window.swaps.last;
      expect(told.title, 'Swap 3/4 +1');
      expect([for (final swap in told.swaps) swap.swapId], [out.id, into.id]);
      expect([for (final swap in told.swaps) swap.label], [_swapOutLabel, _swapInLabel]);
      expect(told.swaps.last.accountId, savingsAccount.accountId);
    });

    testOnMac('names the steps as the row does: deposited by hand, paid to the account or, in preflight, the '
        'recipient', (tester) async {
      final (:window, container: _) = await _open(tester, [_swapIn()]);
      expect(window.swaps.last.swaps.single.steps, [
        'USDC deposited',
        'Confirming on Arbitrum',
        'Swapping',
        'Sending QTC to Main',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      const standIn = SwapPreflight(assetId: 'nep141:stand-in', address: '0xTester');
      final (window: preflight, container: _) = await _open(
        tester,
        [_swapIn()],
        extra: [swapPreflightProvider.overrideWithValue(standIn)],
      );
      expect(preflight.swaps.last.swaps.single.steps.last, 'Sending QTC to the recipient');
    });

    testOnMac('speaks the app\'s language', (tester) async {
      final (:window, :container) = await _open(tester, [fakeActiveSwap()]);

      await container.read(selectedAppLocaleProvider.notifier).select(AppLocale.fromCode('id'));
      await tester.pumpAndSettle();

      expect(window.swaps.last.title, 'Tukar 2/4');
    });
  });

  group('a swap picked from the menu bar icon\'s menu', () {
    testOnMac('brings the window to the front on the swap\'s account, and opens the swap', (tester) async {
      final requests = recordWindowRequests(tester);
      final swap = _swapIn(account: savingsAccount);
      final (:window, :container) = await _open(tester, [swap]);

      window.pickSwap(window.swaps.last.swaps.single);
      await tester.pumpAndSettle();

      expect(requests, contains('bringToFront'));
      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityViewProvider), OpenedSwap(swap.id));
    });

    testOnMac('with the window closed, brings it back and opens the swap', (tester) async {
      final requests = recordWindowRequests(tester);
      final swap = fakeActiveSwap();
      final (:window, :container) = await _open(tester, [swap]);
      final closing = window.pressCloseButton();
      await tester.pump();
      await closing;
      expect(window.calls, ['hide']);

      window.pickSwap(window.swaps.last.swaps.single);
      await tester.pumpAndSettle();

      expect(requests, contains('bringToFront'));
      expect(container.read(openedActivityViewProvider), OpenedSwap(swap.id));
    });

    testOnMac('shows only its account once the swap is no longer followed', (tester) async {
      final swap = _swapIn(account: savingsAccount);
      final (:window, :container) = await _open(tester, [swap]);
      final listed = window.swaps.last.swaps.single;

      await container.read(activeSwapsProvider.notifier).remove(swap.id);
      await tester.pumpAndSettle();
      window.pickSwap(listed);
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), savingsAccount.accountId);
      expect(container.read(openedActivityViewProvider), isNull);
    });

    testOnMac('moves nothing behind an open sheet', (tester) async {
      final swap = _swapIn(account: savingsAccount);
      final (:window, :container) = await _open(tester, [swap]);
      await container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      window.pickSwap(window.swaps.last.swaps.single);
      await tester.pumpAndSettle();

      expect(container.read(shellSheetProvider), ShellSheet.settings);
      expect(_activeAccountId(container), mainAccount.accountId);
      expect(container.read(openedActivityViewProvider), isNull);
    });
  });

  testOnWindowsAndLinux('Windows and Linux are told nothing of swaps', (tester) async {
    final (:window, container: _) = await _open(tester, [fakeActiveSwap()]);

    expect(window.swaps, isEmpty);
  });

  test('a request of the menu bar icon that fails is reported', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final telemetry = _RecordingTelemetry();
    final window = FakeBackgroundWindow()..setSwapsError = StateError('the menu bar refused');
    final container = ProviderContainer(
      overrides: [
        ...shellOverrides(accounts: const [mainAccount]),
        backgroundWindowProvider.overrideWithValue(window),
        telemetryProvider.overrideWithValue(telemetry),
      ],
    );
    addTearDown(container.dispose);

    container.read(backgroundModeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.errors, contains('desktop_background_mode_failed'));
  });
}
