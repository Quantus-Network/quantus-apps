import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations_en.dart';

import '../fakes.dart';

final _l10n = AppLocalizationsEn();

/// Opens Main's wallet, following [swap] if there is one; where swaps are
/// allowed is read from [config].
Future<void> _openWallet(WidgetTester tester, FakeRemoteConfigService config, {ActiveSwap? swap}) {
  return pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount],
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount))..activeSwap = swap,
      balances: oneTokenEach,
      remoteConfig: config,
    ),
  );
}

/// Tells the app its window is [state], as the system would.
Future<void> _window(WidgetTester tester, AppLifecycleState state) async {
  addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pumpAndSettle();
}

Future<void> _pressInToolbar(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the window coming back to the front', () {
    testOnMac('asks again where swaps are allowed, once: the computer may have moved meanwhile', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config);
      // The app's start asks once.
      expect(config.reads, 1);

      await _window(tester, AppLifecycleState.inactive);
      expect(config.reads, 1);

      await _window(tester, AppLifecycleState.resumed);
      expect(config.reads, 2);
    });

    testOnMac('asks once when it was hidden too, not at each step of the way back', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config);

      await _window(tester, AppLifecycleState.inactive);
      await _window(tester, AppLifecycleState.hidden);
      await _window(tester, AppLifecycleState.inactive);
      expect(config.reads, 1);

      await _window(tester, AppLifecycleState.resumed);
      expect(config.reads, 2);
    });

    testOnMac('a verdict that turned against swaps takes Swap off the toolbar', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config);
      expect(find.widgetWithText(ToolbarAction, _l10n.homeSwap), findsOneWidget);

      config.remote = swapsNotOffered;
      await _window(tester, AppLifecycleState.inactive);
      await _window(tester, AppLifecycleState.resumed);

      expect(find.widgetWithText(ToolbarAction, _l10n.homeSwap), findsNothing);
    });
  });

  group('opening a sheet', () {
    testOnMac('Swap asks again where swaps are allowed as it opens', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config);

      await _pressInToolbar(tester, _l10n.homeSwap);

      expect(find.byType(ShellSheetView), findsOneWidget);
      expect(config.reads, 2);
    });

    testOnMac('another sheet does not ask', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config);

      await _pressInToolbar(tester, _l10n.homeReceive);

      expect(find.byType(ShellSheetView), findsOneWidget);
      expect(config.reads, 1);
    });

    testOnMac('Swap asks with a swap followed too: another can start from the form it opens', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openWallet(tester, config, swap: fakeActiveSwap());

      await _pressInToolbar(tester, _l10n.homeSwap);

      expect(find.byType(ShellSheetView), findsOneWidget);
      expect(config.reads, 2);
    });
  });
}
