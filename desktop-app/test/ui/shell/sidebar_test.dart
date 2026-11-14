import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder _row(String title) => _inSidebar(find.widgetWithText(SidebarRow, title));

double _top(WidgetTester tester, String text) => tester.getTopLeft(_inSidebar(find.text(text))).dy;

bool _isSelected(WidgetTester tester, String title) => tester.widget<SidebarRow>(_row(title)).isSelected;

const _allAccounts = [tradingAccount, vaultAccount, savingsAccount, mainAccount, encryptedAccount];

void main() {
  testOnMac('wallets are listed software-first by index, then Keystone, each with its accounts beneath', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: _allAccounts,
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
      ),
    );

    final order = [
      'Wallet 1',
      'Main',
      'Savings',
      'Encrypted Account',
      'Wallet 2',
      'Trading',
      'Cold Wallet',
      'Vault',
    ].map((text) => _top(tester, text)).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(order.toSet(), hasLength(order.length));
  });

  testOnMac('a wallet shows its custom name in place of the numbered one', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, tradingAccount],
        settings: FakeSettingsService(walletNames: const {0: 'Personal'}),
        balances: oneTokenEach,
      ),
    );

    expect(_inSidebar(find.text('Personal')), findsOneWidget);
    expect(_inSidebar(find.text('Wallet 1')), findsNothing);
    expect(_inSidebar(find.text('Wallet 2')), findsOneWidget);
  });

  testOnMac('making an account in another wallet active does not reorder the list', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, tradingAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );

    await tester.tap(_row('Trading'));
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Trading'), isTrue);
    expect(_top(tester, 'Wallet 1'), lessThan(_top(tester, 'Wallet 2')));
    expect(_top(tester, 'Main'), lessThan(_top(tester, 'Trading')));
  });

  testOnMac('a row shows the account name and its formatted balance', (tester) async {
    final balance = oneToken * BigInt.from(3) ~/ BigInt.from(2);
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balances: {'qzMain': balance}),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Sidebar)));
    final formatted = container.read(numberFormattingServiceProvider).formatBalance(balance);
    expect(formatted, contains('1.5'));
    expect(
      find.descendant(of: _row('Main'), matching: find.text('$formatted ${AppConstants.tokenSymbol}')),
      findsOneWidget,
    );
  });

  testOnMac('a row says so while its balance loads', (tester) async {
    final never = Completer<BigInt>();
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balanceOf: (_) => never.future),
    );

    expect(find.descendant(of: _row('Main'), matching: find.text('Loading...')), findsOneWidget);
  });

  testOnMac('a row says the balance is unavailable when it fails to load', (tester) async {
    await pumpShell(tester, overrides: shellOverrides(accounts: const [mainAccount]));

    expect(find.descendant(of: _row('Main'), matching: find.text('Balance unavailable')), findsOneWidget);
  });

  testOnMac('a multisig sits under its owner\'s wallet with the multisig tag; an ownerless one trails the wallets', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(multisigs: [orphanMultisig, teamMultisig]),
        balances: oneTokenEach,
      ),
    );

    expect(find.descendant(of: _row('Team'), matching: find.text('MULTISIG')), findsOneWidget);
    expect(find.descendant(of: _row('Orphan'), matching: find.text('MULTISIG')), findsOneWidget);
    expect(_top(tester, 'Main'), lessThan(_top(tester, 'Team')));
    expect(_top(tester, 'Team'), lessThan(_top(tester, 'Cold Wallet')));
    expect(_top(tester, 'Vault'), lessThan(_top(tester, 'Orphan')));
  });

  testOnMac('the active account is selected; clicking another row makes it the active account', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: settings,
        balances: oneTokenEach,
      ),
    );
    final semantics = tester.ensureSemantics();

    expect(_isSelected(tester, 'Main'), isTrue);
    expect(_isSelected(tester, 'Savings'), isFalse);
    expect(tester.getSemantics(_row('Main')), isSemantics(isSelected: true, isButton: true));

    await tester.tap(_row('Savings'));
    await tester.pumpAndSettle();

    expect(settings.activeAccount?.account.accountId, 'qzSavings');
    expect(_isSelected(tester, 'Savings'), isTrue);
    expect(_isSelected(tester, 'Main'), isFalse);
    expect(tester.getSemantics(_row('Savings')), isSemantics(isSelected: true, isButton: true));
    semantics.dispose();
  });

  testOnMac('a multisig row becomes the active account as a multisig', (tester) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: [teamMultisig]);
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], settings: settings, balances: oneTokenEach),
    );

    await tester.tap(_row('Team'));
    await tester.pumpAndSettle();

    expect(settings.activeAccount, isA<MultisigDisplayAccount>());
    expect(settings.activeAccount?.account.accountId, 'qzTeam');
    expect(_isSelected(tester, 'Team'), isTrue);
  });

  testOnMac('the encrypted account\'s row shows the lock badge and the encrypted balance', (tester) async {
    final balance = oneToken * BigInt.from(7);
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, encryptedAccount],
        balances: oneTokenEach,
        encryptedBalances: {0: balance},
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Sidebar)));
    final formatted = container.read(numberFormattingServiceProvider).formatBalance(balance);
    final row = _row('Encrypted Account');
    expect(find.descendant(of: row, matching: find.byType(EncryptedLockBadge)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('$formatted ${AppConstants.tokenSymbol}')), findsOneWidget);
    expect(find.descendant(of: _row('Main'), matching: find.byType(EncryptedLockBadge)), findsNothing);
  });

  testOnMac('Mining Rewards sits below the accounts; selecting it shows its pane and keeps the active account', (
    tester,
  ) async {
    final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], settings: settings, balances: oneTokenEach),
    );

    expect(_top(tester, 'Main'), lessThan(_top(tester, 'Mining Rewards')));
    expect(find.byType(AccountPane), findsOneWidget);
    expect(find.byType(MiningRewardsPane), findsNothing);

    await tester.tap(_row('Mining Rewards'));
    await tester.pumpAndSettle();

    expect(find.byType(MiningRewardsPane), findsOneWidget);
    expect(find.byType(AccountPane), findsNothing);
    expect(_isSelected(tester, 'Mining Rewards'), isTrue);
    expect(_isSelected(tester, 'Main'), isFalse);
    expect(settings.activeAccount?.account.accountId, 'qzMain');

    await tester.tap(_row('Main'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPane), findsOneWidget);
    expect(_isSelected(tester, 'Main'), isTrue);
    expect(_isSelected(tester, 'Mining Rewards'), isFalse);
  });

  testOnMac('Add Account sits at the bottom and opens the Add Account sheet', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
    );

    expect(_top(tester, 'Mining Rewards'), lessThan(_top(tester, 'Add Account')));

    await tester.tap(_inSidebar(find.text('Add Account')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(ShellSheetView), matching: find.text('Add Account')), findsOneWidget);
  });

  testOnMac('a loader shows while the accounts load', (tester) async {
    final never = Completer<List<Account>>();
    await pumpShell(tester, overrides: shellOverrides(loadAccounts: () => never.future), settle: false);

    expect(_inSidebar(find.byType(Loader)), findsOneWidget);
  });

  testOnMac('a failed load says the accounts failed to load', (tester) async {
    await pumpShell(tester, overrides: shellOverrides(loadAccounts: () async => throw StateError('storage is gone')));

    expect(_inSidebar(find.text('Failed to load accounts.')), findsOneWidget);
  });

  testOnMac('an empty wallet says no accounts were found', (tester) async {
    await pumpShell(tester, overrides: shellOverrides());

    expect(_inSidebar(find.text('No accounts found.')), findsOneWidget);
  });
}
