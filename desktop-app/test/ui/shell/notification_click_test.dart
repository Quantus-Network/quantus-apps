import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';

import '../../fakes.dart';
import '../../services/fake_notification_plugin.dart';

/// Opens the window on a wallet whose active account is Main, its accounts
/// loaded by [loadAccounts] when given.
Future<ProviderContainer> _openWallet(
  WidgetTester tester,
  FakeNotificationPlugin notifications, {
  Future<List<Account>> Function()? loadAccounts,
  bool settle = true,
}) async {
  await pumpShell(
    tester,
    notifications: notifications,
    settle: settle,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount],
      loadAccounts: loadAccounts,
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
}

/// What a notification about [accountId] carries.
String _about(String accountId) => jsonEncode({'accountId': accountId});

String? _activeAccountId(ProviderContainer container) => container.read(activeAccountProvider).value?.account.accountId;

Future<void> _clickSelectsTheAccount(WidgetTester tester) async {
  final notifications = FakeNotificationPlugin();
  final window = recordWindowRequests(tester);
  final container = await _openWallet(tester, notifications);

  notifications.click(_about(savingsAccount.accountId));
  await tester.pumpAndSettle();

  expect(window, ['bringToFront']);
  expect(_activeAccountId(container), savingsAccount.accountId);
}

void main() {
  testOnMac(
    'clicking a notification brings the window forward and selects the account it was about',
    _clickSelectsTheAccount,
  );

  testOnWindowsAndLinux(
    'clicking a notification brings the window forward and selects the account it was about',
    _clickSelectsTheAccount,
  );

  testOnMac('a click about an account that is gone since only brings the window forward', (tester) async {
    final notifications = FakeNotificationPlugin();
    final window = recordWindowRequests(tester);
    final container = await _openWallet(tester, notifications);

    notifications.click(_about('qzGone'));
    await tester.pumpAndSettle();

    expect(window, ['bringToFront']);
    expect(_activeAccountId(container), mainAccount.accountId);
  });

  testOnMac('a click that launched the app opens the account it was about', (tester) async {
    final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
    final window = recordWindowRequests(tester);
    final container = await _openWallet(tester, notifications);

    expect(window, ['bringToFront']);
    expect(_activeAccountId(container), savingsAccount.accountId);
  });

  testOnMac("a click that launched the app waits for the wallet's accounts to load", (tester) async {
    final accounts = Completer<List<Account>>();
    final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
    final container = await _openWallet(tester, notifications, loadAccounts: () => accounts.future, settle: false);
    await tester.pump(const Duration(milliseconds: 100));

    accounts.complete(const [mainAccount, savingsAccount]);
    await tester.pumpAndSettle();

    expect(_activeAccountId(container), savingsAccount.accountId);
  });

  for (final refused in [false, true]) {
    testOnMac('a reset drops a click still waiting for the accounts${refused ? ', even if the system refuses' : ''}', (
      tester,
    ) async {
      final accounts = Completer<List<Account>>();
      final notifications = FakeNotificationPlugin(launchedBy: _about(savingsAccount.accountId));
      if (refused) notifications.cancelAllError = StateError('refused');
      final container = await _openWallet(tester, notifications, loadAccounts: () => accounts.future, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      await container
          .read(desktopLocalNotificationsProvider.notifier)
          .cancelAll()
          .catchError((Object _) {}, test: (_) => refused);
      accounts.complete(const [mainAccount, savingsAccount]);
      await tester.pumpAndSettle();

      expect(_activeAccountId(container), mainAccount.accountId);
    });
  }
}
