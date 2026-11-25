import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/background_mode.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/utils/notification_id.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';

import '../fakes.dart';
import 'fake_background_window.dart';
import 'fake_notification_plugin.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// What a swap's notification says it was about, as its row does: 250 QTC
/// out for 104.37 USDC, or 100 USDC in for 236.9 QTC.
const _swapOutBody = '-250 QTC for 104.37 USDC on Arbitrum';
const _swapInBody = '+236.9 QTC for 100 USDC on Arbitrum';

/// A swap into QTC whose deposit was made by hand, at [depositAddress].
ActiveSwap _swapIn({String depositAddress = '0x1111111111111111111111111111111111111111'}) =>
    fakeActiveSwap(swapOut: false, depositSent: true, depositAddress: depositAddress);

/// 1Click answering [status] for every swap asked about.
Future<SwapOrder> Function(SwapOrder) _answering(SwapStatus status) =>
    (order) async => SwapOrder(quote: order.quote, status: status);

/// Opens Main's wallet following [swaps], with 1Click as [oneClick] answers.
Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeNotificationPlugin notifications,
  FakeSwapService oneClick,
  List<ActiveSwap> swaps, {
  FakeBackgroundWindow? window,
  List<Override> extra = const [],
}) async {
  await pumpShell(
    tester,
    notifications: notifications,
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
  return ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
}

Future<void> _interval(WidgetTester tester) => tester.pump(SwapService.statusPollInterval);

List<String> _titles(FakeNotificationPlugin notifications) => [for (final shown in notifications.shown) shown.title];

void main() {
  testOnMac('a swap that succeeds is told once, as its row says it', (tester) async {
    final notifications = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    final swap = fakeActiveSwap();
    await _open(tester, notifications, oneClick, [swap]);
    expect(notifications.shown, isEmpty);

    oneClick.status = _answering(SwapStatus.success);
    await _interval(tester);

    final shown = notifications.shown.single;
    expect(shown.title, _l10n.swapLiveSwapped);
    expect(shown.body, _swapOutBody);
    expect(shown.id, notificationSystemId('swap_end_${swap.id}'));

    await _interval(tester);
    await _interval(tester);
    expect(notifications.shown, hasLength(1));
  });

  testOnMac('a refunded swap is told as Refunded, and a failed one as Swap Failed', (tester) async {
    for (final (status, title) in [
      (SwapStatus.refunded, _l10n.swapRefundedLabel),
      (SwapStatus.failed, _l10n.swapFailedTitle),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final notifications = FakeNotificationPlugin();
      final oneClick = FakeSwapService();
      await _open(tester, notifications, oneClick, [fakeActiveSwap()]);

      oneClick.status = _answering(status);
      await _interval(tester);

      expect(_titles(notifications), [title], reason: '$status');
      expect(notifications.shown.single.body, _swapOutBody);
    }
  });

  testOnMac('a deposit that came short is told at once, and its refund after', (tester) async {
    final notifications = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    final swap = _swapIn();
    await _open(tester, notifications, oneClick, [swap]);

    oneClick.status = _answering(SwapStatus.incompleteDeposit);
    await _interval(tester);
    await _interval(tester);

    expect(_titles(notifications), [_l10n.swapDepositIncompleteTitle]);
    expect(notifications.shown.single.body, _swapInBody);
    expect(notifications.shown.single.id, notificationSystemId('swap_short_${swap.id}'));

    oneClick.status = _answering(SwapStatus.refunded);
    await _interval(tester);

    expect(_titles(notifications), [_l10n.swapDepositIncompleteTitle, _l10n.swapRefundedLabel]);
    expect(notifications.shown.last.id, notificationSystemId('swap_end_${swap.id}'));
  });

  testOnMac('a swap that had ended, or come short, before the app started is not told again', (tester) async {
    final notifications = FakeNotificationPlugin();
    await _open(tester, notifications, FakeSwapService(), [
      fakeActiveSwap(status: SwapStatus.success),
      fakeActiveSwap(
        swapOut: false,
        depositSent: true,
        status: SwapStatus.incompleteDeposit,
        depositAddress: '0x2222222222222222222222222222222222222222',
      ),
    ]);

    await _interval(tester);
    await _interval(tester);

    expect(notifications.shown, isEmpty);
  });

  testOnMac('a swap that ended, or came short, while the app was not running is told at its first poll', (
    tester,
  ) async {
    final notifications = FakeNotificationPlugin();
    final ending = fakeActiveSwap();
    final short = _swapIn();
    final oneClick = FakeSwapService()
      ..status = (order) async => SwapOrder(
        quote: order.quote,
        status: order.depositAddress == ending.order.depositAddress ? SwapStatus.success : SwapStatus.incompleteDeposit,
      );
    await _open(tester, notifications, oneClick, [ending, short]);
    await _interval(tester);

    expect(_titles(notifications), unorderedEquals([_l10n.swapLiveSwapped, _l10n.swapDepositIncompleteTitle]));
  });

  testOnMac('a deposit by hand whose window closed with nothing sent is not told', (tester) async {
    final notifications = FakeNotificationPlugin();
    await _open(tester, notifications, FakeSwapService(), [
      fakeActiveSwap(
        swapOut: false,
        status: SwapStatus.pendingDeposit,
        deadline: clock.now().add(const Duration(minutes: 1)),
      ),
    ]);

    await tester.pump(const Duration(minutes: 1) + ActiveSwap.finishGrace + SwapService.statusPollInterval);

    expect(notifications.shown, isEmpty);
  });

  testOnMac('a swap put away before it ended is not told', (tester) async {
    final notifications = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    final swap = fakeActiveSwap();
    final container = await _open(tester, notifications, oneClick, [swap]);

    await container.read(activeSwapsProvider.notifier).remove(swap.id);
    oneClick.status = _answering(SwapStatus.success);
    await _interval(tester);
    await container.read(activeSwapsProvider.notifier).refresh();

    expect(notifications.shown, isEmpty);
  });

  testOnMac('a swap that ends while the window is out of sight is told: its polls go on', (tester) async {
    final notifications = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    await _open(tester, notifications, oneClick, [fakeActiveSwap()]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    oneClick.status = _answering(SwapStatus.success);
    await _interval(tester);

    expect(_titles(notifications), [_l10n.swapLiveSwapped]);
  });

  testOnMac('a swap that ends with the window closed is told, and then the app quits', (tester) async {
    final notifications = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    final window = FakeBackgroundWindow();
    final exits = <String>[];
    await _open(
      tester,
      notifications,
      oneClick,
      [fakeActiveSwap()],
      window: window,
      extra: [requestAppExitProvider.overrideWithValue(() => exits.add('exit'))],
    );
    final closing = window.pressCloseButton();
    await tester.pump();
    await closing;
    expect(window.calls, ['hide']);

    oneClick.status = _answering(SwapStatus.success);
    await _interval(tester);
    expect(_titles(notifications), [_l10n.swapLiveSwapped]);
    expect(exits, isEmpty, reason: 'not before the notification is on its way');

    await tester.pump(BackgroundMode.settleDelay * 3);
    expect(exits, ['exit']);
  });

  testOnMac('nothing is told with notifications off in Settings, or not allowed by macOS', (tester) async {
    const off = NotificationConfig(
      enabled: false,
      sound: true,
      vibration: true,
      showBadge: true,
      sentTokensEnabled: true,
      receivedTokensEnabled: true,
      recoveryTimerEndingEnabled: true,
      reversibleTransactionsEnabled: true,
    );
    SharedPreferences.setMockInitialValues({notificationConfigKey: jsonEncode(off.toJson())});
    final offInSettings = FakeNotificationPlugin();
    final oneClick = FakeSwapService();
    await _open(tester, offInSettings, oneClick, [fakeActiveSwap()]);
    oneClick.status = _answering(SwapStatus.success);
    await _interval(tester);
    expect(offInSettings.shown, isEmpty, reason: 'off in Settings');

    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({});
    final notAllowed = FakeNotificationPlugin(grants: false);
    final again = FakeSwapService();
    await _open(tester, notAllowed, again, [fakeActiveSwap()]);
    again.status = _answering(SwapStatus.success);
    await _interval(tester);
    expect(notAllowed.shown, isEmpty, reason: 'not allowed by macOS');
  });
}
