import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

Finder _inPane(Finder matching) => find.descendant(of: find.byType(AccountPane), matching: matching);

Finder _toolbarButton(String label) =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, label));

List<String> _toolbarLabels(WidgetTester tester) => [
  for (final label in ['Receive', 'Send', 'Propose', 'Swap'])
    if (_toolbarButton(label).evaluate().isNotEmpty) label,
];

Finder _inBalanceCard(Finder matching) => find.descendant(of: find.byType(BalanceCard), matching: matching);

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
  testOnMac('the balance\'s panel shows the active account\'s balance, and no name above it', (tester) async {
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
    expect(find.descendant(of: find.byType(ShellTopBar), matching: find.text('Main')), findsNothing);
    expect(_inPane(find.text('Main')), findsNothing);
    expect(_inBalanceCard(find.text(formatted)), findsOneWidget);
  });

  testOnMac('the balance sits in a card labelled BALANCE: the amount large, the token symbol small after it', (
    tester,
  ) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountPane)));
    final amount = _inBalanceCard(find.text(container.read(numberFormattingServiceProvider).formatBalance(oneToken)));
    final symbol = _inBalanceCard(find.text(AppConstants.tokenSymbol));
    expect(_inBalanceCard(find.text('BALANCE')), findsOneWidget);
    expect(_inBalanceCard(find.bySemanticsLabel('Balance')), findsOneWidget);
    expect(tester.getTopLeft(_inBalanceCard(find.text('BALANCE'))).dy, lessThan(tester.getTopLeft(amount).dy));
    expect(tester.getTopLeft(symbol).dx, greaterThan(tester.getTopRight(amount).dx));
    expect(tester.widget<Text>(amount).style!.fontSize, greaterThan(2 * tester.widget<Text>(symbol).style!.fontSize!));
    // The card runs the width of the pane; the shell keeps the gaps around it.
    final card = tester.getRect(find.byType(BalanceCard));
    final pane = tester.getRect(find.byType(AccountPane));
    expect(card.left, pane.left);
    expect(card.right, pane.right);
  });

  testOnMac('while the balance loads the card says so, and it says when the balance is unavailable', (tester) async {
    final arrives = Completer<BigInt>();
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balanceOf: (_) => arrives.future,
      ),
      settle: false,
    );
    await tester.pump();

    expect(_inBalanceCard(find.text('Loading...')), findsOneWidget);
    expect(_inBalanceCard(find.text(AppConstants.tokenSymbol)), findsNothing);

    arrives.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(_inBalanceCard(find.text('Balance unavailable')), findsOneWidget);
    expect(_inBalanceCard(find.text(AppConstants.tokenSymbol)), findsNothing);
  });

  testOnMac('the balance is a panel right under the top bar', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    final bar = tester.getRect(find.byType(ShellTopBar));
    final balance = tester.getRect(find.byType(BalanceCard));
    expect(balance.top, bar.bottom);
    expect(find.descendant(of: find.byType(BalanceCard), matching: find.byType(Panel)), findsOneWidget);
  });

  testOnMac('a local account\'s toolbar offers Receive, Send and Swap', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(_toolbarLabels(tester), ['Receive', 'Send', 'Swap']);
  });

  testOnMac('each toolbar action carries the icon the mobile app gives it', (tester) async {
    QuantusIcons iconOf(String label) =>
        tester.widget<QuantusIcon>(find.descendant(of: _toolbarButton(label), matching: find.byType(QuantusIcon))).icon;

    await _pumpWithActive(tester, const RegularAccount(mainAccount));

    expect(iconOf('Receive'), QuantusIcons.actionReceive);
    expect(iconOf('Send'), QuantusIcons.actionSend);
    expect(iconOf('Swap'), QuantusIcons.actionSwap);
  });

  testOnMac('Propose carries the Send icon, as on the mobile app', (tester) async {
    await _pumpWithActive(tester, MultisigDisplayAccount(teamMultisig));

    expect(
      tester
          .widget<QuantusIcon>(find.descendant(of: _toolbarButton('Propose'), matching: find.byType(QuantusIcon)))
          .icon,
      QuantusIcons.actionSend,
    );
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
    await tester.tap(find.descendant(of: find.byType(ShellSheetView), matching: find.byTooltip('Close')));
    await tester.pumpAndSettle();

    expect(find.byType(ShellSheetView), findsNothing);

    await tester.tap(_toolbarButton('Receive'));
    await tester.pumpAndSettle();

    expect(_sheetTitled('Receive'), findsOneWidget);
  });

  // The sidebar's row and its lock already say it is the Encrypted account
  // (the user's call, round 31): the phone's notice is not needed here.
  testOnMac('on the encrypted account the pane shows no private-account notice', (tester) async {
    await _pumpWithActive(tester, const RegularAccount(encryptedAccount));

    expect(_inPane(find.byType(PrivateActivityNotice)), findsNothing);
    expect(_inPane(find.text('Hides the link between your account and the recipient')), findsNothing);
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
