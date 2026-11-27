import 'dart:async';

import 'package:flutter/widgets.dart' show Rect, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_marks_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
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
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), openWallets: const {1, 2}),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
      ),
    );

    final order = [
      'WALLET 1',
      'Main',
      'Savings',
      'Encrypted Account',
      'WALLET 2',
      'Trading',
      'COLD WALLET',
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

    expect(_inSidebar(find.text('PERSONAL')), findsOneWidget);
    expect(_inSidebar(find.text('WALLET 1')), findsNothing);
    expect(_inSidebar(find.text('WALLET 2')), findsOneWidget);
  });

  testOnMac('a cold wallet keeps its numbered name, whatever name is saved for it', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(walletNames: const {0: 'Personal', 1: 'Ledger'}),
        balances: oneTokenEach,
      ),
    );

    expect(_inSidebar(find.text('PERSONAL')), findsOneWidget);
    expect(_inSidebar(find.text('COLD WALLET')), findsOneWidget);
    expect(_inSidebar(find.text('LEDGER')), findsNothing);
  });

  testOnMac('making an account in another wallet active does not reorder the list', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, tradingAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), openWallets: const {2}),
        balances: oneTokenEach,
      ),
    );

    await tester.tap(_row('Trading'));
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Trading'), isTrue);
    expect(_top(tester, 'WALLET 1'), lessThan(_top(tester, 'WALLET 2')));
    expect(_top(tester, 'Main'), lessThan(_top(tester, 'Trading')));
  });

  testOnMac('a row shows the account name and its formatted balance', (tester) async {
    final balance = oneToken * BigInt.from(3) ~/ BigInt.from(2);
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {'qzMain': balance},
      ),
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
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balanceOf: (_) => never.future,
      ),
    );

    expect(find.descendant(of: _row('Main'), matching: find.text('Loading...')), findsOneWidget);
  });

  testOnMac('a row says the balance is unavailable when it fails to load', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
      ),
    );

    expect(find.descendant(of: _row('Main'), matching: find.text('Balance unavailable')), findsOneWidget);
  });

  testOnMac('every multisig sits under MULTISIGS after the wallets, by name, with no tag', (tester) async {
    final coldTeam = MultisigAccount(
      name: 'Cold Team',
      accountId: 'qzColdTeam',
      signers: const ['qzVault', 'qzOther'],
      threshold: 2,
      nonce: BigInt.zero,
      myMemberAccountId: 'qzVault',
    );
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(
          activeAccount: const RegularAccount(mainAccount),
          multisigs: [orphanMultisig, teamMultisig, coldTeam],
          openWallets: const {1},
          multisigsOpen: true,
        ),
        balances: oneTokenEach,
      ),
    );

    final order = [
      'WALLET 1',
      'Main',
      'COLD WALLET',
      'Vault',
      'MULTISIGS',
      'Cold Team',
      'Orphan',
      'Team',
    ].map((text) => _top(tester, text)).toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(order.toSet(), hasLength(order.length));
    expect(_inSidebar(find.text('MULTISIG')), findsNothing);
  });

  testOnMac('with no multisig there is no MULTISIGS heading', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigsOpen: true),
        balances: oneTokenEach,
      ),
    );

    expect(_inSidebar(find.text('MULTISIGS')), findsNothing);
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
    final settings = FakeSettingsService(
      activeAccount: const RegularAccount(mainAccount),
      multisigs: [teamMultisig],
      multisigsOpen: true,
    );
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

  testOnMac('every account row has a badge: initials for an account, the lock for the encrypted one', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, encryptedAccount, vaultAccount],
        settings: FakeSettingsService(
          activeAccount: const RegularAccount(mainAccount),
          multisigs: [teamMultisig],
          openWallets: const {1},
          multisigsOpen: true,
        ),
        balances: oneTokenEach,
        encryptedBalances: {0: oneToken},
      ),
    );

    for (final name in ['Main', 'Vault', 'Team']) {
      final badge = find.descendant(of: _row(name), matching: find.byType(AccountBadge));
      expect(tester.widget<AccountBadge>(badge).name, name);
      expect(find.descendant(of: _row(name), matching: find.byType(EncryptedLockBadge)), findsNothing);
    }
    expect(find.descendant(of: _row('Encrypted Account'), matching: find.byType(AccountBadge)), findsNothing);
    expect(find.descendant(of: _row('Encrypted Account'), matching: find.byType(EncryptedLockBadge)), findsOneWidget);

    for (final name in ['Main', 'Vault', 'Team', 'Encrypted Account']) {
      final badge = find.descendant(of: _row(name), matching: find.byType(DesktopAccountBadge));
      expect(tester.getSize(badge), const Size.square(32), reason: name);
    }

    // The names line up whichever badge a row has.
    final nameLefts = {
      for (final name in ['Main', 'Vault', 'Team', 'Encrypted Account'])
        tester.getTopLeft(find.descendant(of: _row(name), matching: find.text(name))).dx,
    };
    expect(nameLefts, hasLength(1));
  });

  testOnMac('a wallet\'s label is drawn in capitals but read out as it is written', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
    );

    expect(_inSidebar(find.text('WALLET 1')), findsOneWidget);
    expect(_inSidebar(find.bySemanticsLabel('Wallet 1')), findsOneWidget);
  });

  testOnMac('the encrypted account\'s row shows the lock badge and the encrypted balance', (tester) async {
    final balance = oneToken * BigInt.from(7);
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
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

  testOnMac('the list holds only the accounts: no Mining Rewards row, and Settings and Add Account follow', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );

    expect(_inSidebar(find.text('Mining Rewards')), findsNothing);
    expect(
      tester
          .widgetList<SidebarRow>(find.descendant(of: find.byType(Sidebar), matching: find.byType(SidebarRow)))
          .map((row) => row.title),
      ['Main', 'Settings', 'Add Account'],
    );
    expect(find.byType(AccountPane), findsOneWidget);
  });

  testOnMac('Add Account sits at the bottom and opens its menu', (tester) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );

    expect(_top(tester, 'Main'), lessThan(_top(tester, 'Add Account')));

    await tester.tap(_inSidebar(find.text('Add Account')));
    await tester.pumpAndSettle();

    expect(find.byKey(ContextMenuRegion.menuKey), findsOneWidget);
    expect(find.byType(ShellSheetView), findsNothing);
  });

  testOnMac('Settings sits in the foot right above Add Account, on its edge, and opens the Settings sheet', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: oneTokenEach,
      ),
    );

    final settings = tester.getRect(_row('Settings'));
    final addAccount = tester.getRect(_row('Add Account'));
    expect(_top(tester, 'Main'), lessThan(settings.top));
    expect(settings.bottom, lessThanOrEqualTo(addAccount.top));
    expect(addAccount.top - settings.bottom, lessThan(6));
    expect(settings.left, addAccount.left);
    expect(settings.height, addAccount.height);
    expect(
      tester.getRect(_inSidebar(find.text('Settings'))).left,
      tester.getRect(_inSidebar(find.text('Add Account'))).left,
    );

    await tester.tap(_inSidebar(find.text('Settings')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(ShellSheetView), matching: find.text('Settings')), findsOneWidget);
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

  group('what an account has in progress', () {
    /// Main, Savings, and two multisigs; Savings has a transfer on its way and
    /// Team two proposals waiting for this wallet's signature.
    Future<void> open(WidgetTester tester) => pumpShell(
      tester,
      overrides: [
        ...shellOverrides(
          accounts: const [mainAccount, savingsAccount],
          settings: FakeSettingsService(
            activeAccount: const RegularAccount(mainAccount),
            multisigs: [teamMultisig, orphanMultisig],
            multisigsOpen: true,
          ),
          balances: oneTokenEach,
        ),
        accountMarksProvider.overrideWithValue({
          savingsAccount.accountId: const AccountMark(inProgress: 1),
          teamMultisig.accountId: const AccountMark(waitingForSignature: 2),
        }),
      ],
    );

    Finder countIn(String row) => find.descendant(of: _row(row), matching: find.byKey(DesktopAccountBadge.countKey));

    testOnMac("an account with some shows how many on its badge's corner; one without shows none", (tester) async {
      await open(tester);

      expect(find.descendant(of: countIn('Savings'), matching: find.text('1')), findsOne);
      expect(find.descendant(of: countIn('Team'), matching: find.text('2')), findsOne);
      expect(countIn('Main'), findsNothing);
      expect(countIn('Orphan'), findsNothing);

      final badge = tester.getRect(find.descendant(of: _row('Savings'), matching: find.byType(DesktopAccountBadge)));
      final count = tester.getRect(countIn('Savings'));
      expect(count.center.dx, greaterThan(badge.center.dx));
      expect(count.center.dy, lessThan(badge.center.dy));
      expect(count.right, greaterThan(badge.right - 4), reason: 'on the corner, not inside the badge');
    });

    testOnMac('the count moves nothing in its row: the name and the balance stay where they are', (tester) async {
      await open(tester);

      Rect within(String row, Finder part) {
        final rowRect = tester.getRect(_row(row));
        return tester.getRect(find.descendant(of: _row(row), matching: part)).shift(-rowRect.topLeft);
      }

      // Team has a count, Orphan none; both are multisigs alike.
      expect(within('Team', find.text('Team')).topLeft, within('Orphan', find.text('Orphan')).topLeft);
      expect(within('Team', find.text('1 QTC')), within('Orphan', find.text('1 QTC')));
    });

    testOnMac('a screen reader hears how many, and of what', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);

      expect(find.bySemanticsLabel(RegExp('1 in progress')), findsOne);
      expect(find.bySemanticsLabel(RegExp('2 waiting for your signature')), findsOne);
      semantics.dispose();
    });
  });
}
