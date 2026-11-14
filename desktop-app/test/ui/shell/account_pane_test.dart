import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

Finder _inPane(Finder matching) => find.descendant(of: find.byType(AccountPane), matching: matching);

Finder _toolbarButton(String label) =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(QuantusButton, label));

List<String> _toolbarLabels(WidgetTester tester) => [
  for (final label in ['Receive', 'Send', 'Propose', 'Swap'])
    if (_toolbarButton(label).evaluate().isNotEmpty) label,
];

Finder _sheetTitled(String title) => find.descendant(of: find.byType(ShellSheetView), matching: find.text(title));

Future<void> _pumpWithActive(WidgetTester tester, DisplayAccount active, {bool swapAvailable = true}) {
  return pumpShell(
    tester,
    overrides: shellOverrides(
      accounts: const [mainAccount, encryptedAccount, vaultAccount],
      settings: FakeSettingsService(activeAccount: active, multisigs: [teamMultisig]),
      balances: oneTokenEach,
      encryptedBalances: {0: oneToken},
      swapAvailable: swapAvailable,
    ),
  );
}

void main() {
  testOnMac('the header shows the active account\'s name and the pane its balance', (tester) async {
    final balance = oneToken * BigInt.from(5);
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {'qzMain': balance},
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountPane)));
    final formatted = container.read(numberFormattingServiceProvider).formatBalance(balance);
    expect(find.descendant(of: find.byType(PaneHeader), matching: find.text('Main')), findsOneWidget);
    expect(_inPane(find.text('Main')), findsNothing);
    expect(_inPane(find.text('$formatted ${AppConstants.tokenSymbol}')), findsOneWidget);
  });

  testOnMac('a local account\'s toolbar offers Receive, Send and Swap', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(_toolbarLabels(tester), ['Receive', 'Send', 'Swap']);
  });

  testOnMac('where swaps are not offered the toolbar has no Swap', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount), swapAvailable: false);

    expect(_toolbarLabels(tester), ['Receive', 'Send']);
  });

  testOnMac('a multisig\'s toolbar offers Receive and Propose', (tester) async {
    await _pumpWithActive(tester, MultisigDisplayAccount(teamMultisig));

    expect(_toolbarLabels(tester), ['Receive', 'Propose']);
  });

  testOnMac('a Keystone account\'s Swap is shown disabled and opens nothing', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(vaultAccount));

    expect(_toolbarLabels(tester), ['Receive', 'Send', 'Swap']);

    await tester.tap(_toolbarButton('Swap'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);
  });

  for (final (account, label) in <(DisplayAccount, String)>[
    (const RegularAccount(mainAccount), 'Receive'),
    (const RegularAccount(mainAccount), 'Send'),
    (const RegularAccount(mainAccount), 'Swap'),
    (MultisigDisplayAccount(teamMultisig), 'Propose'),
  ]) {
    testOnMac('$label opens a sheet with its title, and Esc closes it', (tester) async {
      await _pumpWithActive(tester, account);

      await tester.tap(_toolbarButton(label));
      await tester.pumpAndSettle();

      expect(_sheetTitled(label), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  }

  testOnMac('a sheet\'s Close button closes it, and another sheet can open afterwards', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    await tester.tap(_toolbarButton('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ShellSheetView), matching: find.text('Close')));
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);

    await tester.tap(_toolbarButton('Receive'));
    await tester.pumpAndSettle();

    expect(_sheetTitled('Receive'), findsOneWidget);
  });

  testOnMac('on the encrypted account the pane shows the lock badge and the private-account notice', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(encryptedAccount));

    expect(_inPane(find.byType(PrivateActivityNotice)), findsOneWidget);
    expect(_inPane(find.text('Hides the link between your account and the recipient')), findsOneWidget);
    expect(_inPane(find.byType(EncryptedLockBadge)), findsWidgets);
  });

  testOnMac('on a transparent account the pane shows no private-account notice', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(_inPane(find.byType(PrivateActivityNotice)), findsNothing);
    expect(_inPane(find.byType(EncryptedLockBadge)), findsNothing);
  });

  testOnMac('with no active account the pane says so and has no toolbar', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
    );

    expect(_inPane(find.text('No active account')), findsOneWidget);
    expect(find.byType(AccountToolbar), findsNothing);
  });
}
