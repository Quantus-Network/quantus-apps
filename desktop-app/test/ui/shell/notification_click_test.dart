import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';

import '../../fakes.dart';
import '../../services/fake_notification_plugin.dart';

/// Opens the window on a wallet whose active account is Main.
Future<ProviderContainer> _openWallet(WidgetTester tester, FakeNotificationPlugin notifications) async {
  await pumpShell(
    tester,
    notifications: notifications,
    overrides: shellOverrides(
      accounts: const [mainAccount, savingsAccount],
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
}
