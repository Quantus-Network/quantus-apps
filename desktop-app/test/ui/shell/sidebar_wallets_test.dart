import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

const _travel = Account(walletIndex: 3, index: 0, name: 'Travel', accountId: 'qzTravel');

/// Main (active) and Savings in Wallet 1, Trading in Wallet 2, Travel in
/// Wallet 3, Vault in the Cold Wallet, and any [multisigs]. The app gives each
/// software wallet its Encrypted account as well.
Future<FakeWalletDevice> _pump(WidgetTester tester, {List<MultisigAccount> multisigs = const []}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll([vaultAccount, tradingAccount, _travel]);
  device.storage.mnemonics[2] = 'trading words';
  device.storage.mnemonics[3] = 'travel words';
  device.storage.multisigStore.addAll(multisigs);
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      sensitiveClipboardProvider.overrideWithValue(FakeSensitiveClipboard()),
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => 'qzDeposit', innerHash: () async => '0xinner'),
      ),
    ],
  );
  return device;
}

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder _text(String text) => _inSidebar(find.text(text));

Finder _row(String title) => _inSidebar(find.widgetWithText(SidebarRow, title));

Finder _chevron(String heading, IconData icon) => find.descendant(
  of: find.ancestor(of: _text(heading), matching: find.byType(Row)).first,
  matching: find.byIcon(icon),
);

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder get _field => _inSidebar(find.byType(EditableText));

List<PlatformMenuItem> _itemsOf(WidgetTester tester, String label) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == label).menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
}

Future<void> _choose(WidgetTester tester, String menu, String label) async {
  _itemsOf(tester, menu).singleWhere((item) => item.label == label).onSelected!();
  await tester.pumpAndSettle();
}

Future<void> _click(WidgetTester tester, String text) async {
  await tester.tap(_text(text));
  await tester.pumpAndSettle();
}

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// [count] tokens as the sidebar writes an amount.
String _tokens(WidgetTester tester, int count) {
  final container = ProviderScope.containerOf(tester.element(find.byType(Sidebar)));
  final formatted = container.read(numberFormattingServiceProvider).formatBalance(oneToken * BigInt.from(count));
  return '$formatted ${AppConstants.tokenSymbol}';
}

/// [text] in the heading keyed [headingKey].
Finder _under(String headingKey, String text) =>
    find.descendant(of: find.byKey(ValueKey(headingKey)), matching: find.text(text));

String _selected(WidgetTester tester) =>
    tester.widgetList<SidebarRow>(_inSidebar(find.byType(SidebarRow))).singleWhere((row) => row.isSelected).title;

void main() {
  testOnMac('a closed wallet shows how many accounts it holds; a click opens it, and closes it again', (tester) async {
    await _pump(tester);

    expect(_row('Trading'), findsNothing);
    expect(_chevron('WALLET 2', CupertinoIcons.chevron_right), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: _text('WALLET 2'), matching: find.byType(Row)).first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await _click(tester, 'WALLET 2');
    expect(_row('Trading'), findsOneWidget);
    expect(_chevron('WALLET 2', CupertinoIcons.chevron_down), findsOneWidget);

    await _click(tester, 'WALLET 2');
    expect(_row('Trading'), findsNothing);
  });

  testOnMac('the active account\'s wallet has no chevron, and a click leaves it open', (tester) async {
    await _pump(tester);

    expect(_chevron('WALLET 1', CupertinoIcons.chevron_down), findsNothing);
    expect(_chevron('WALLET 1', CupertinoIcons.chevron_right), findsNothing);

    await _click(tester, 'WALLET 1');
    expect(_row('Main'), findsOneWidget);
    expect(_row('Savings'), findsOneWidget);
  });

  testOnMac('an account in a closed wallet becoming active opens it, and it stays open after', (tester) async {
    await _pump(tester);

    await _choose(tester, 'Account', 'Trading');
    expect(_selected(tester), 'Trading');
    expect(_chevron('WALLET 2', CupertinoIcons.chevron_down), findsNothing, reason: 'it is the active wallet now');

    await _choose(tester, 'Account', 'Main');
    expect(_row('Trading'), findsOneWidget);
    expect(_chevron('WALLET 2', CupertinoIcons.chevron_down), findsOneWidget);
  });

  testOnMac('clicking an account in another open wallet moves no row', (tester) async {
    await _pump(tester);
    await _click(tester, 'WALLET 2');
    final before = tester.getRect(_row('Trading'));

    await tester.tap(_row('Trading'));
    await tester.pumpAndSettle();

    expect(_selected(tester), 'Trading');
    expect(tester.getRect(_row('Trading')), before);
    expect(_row('Main'), findsOneWidget);
  });

  testOnMac('Next and Previous Sidebar Item step over the accounts of closed wallets', (tester) async {
    await _pump(tester);

    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Savings');
    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Encrypted Account');
    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Main');
    await _choose(tester, 'View', 'Previous Sidebar Item');
    expect(_selected(tester), 'Encrypted Account');
  });

  testOnMac('the accounts keep their ⌘ numbers while their wallets are closed', (tester) async {
    await _pump(tester);
    List<LogicalKeyboardKey?> numbers() => [
      for (final name in ['Main', 'Savings', 'Trading', 'Travel', 'Vault'])
        (_itemsOf(tester, 'Account').singleWhere((item) => item.label == name).shortcut as SingleActivator?)?.trigger,
    ];
    const expected = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit8,
    ];

    expect(numbers(), expected);
    await _click(tester, 'WALLET 2');
    expect(numbers(), expected);
  });

  testOnMac('a right-click on a closed heading opens its menu and leaves it closed', (tester) async {
    await _pump(tester);

    await _rightClick(tester, _text('WALLET 2'));
    expect(_menu, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_row('Trading'), findsNothing);
  });

  testOnMac('a Control-click on a closed heading opens its menu and leaves it closed', (tester) async {
    await _pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final gesture = await tester.startGesture(
      tester.getCenter(_text('WALLET 2')),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_menu, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_row('Trading'), findsNothing);
  });

  testOnMac('a closed wallet can be renamed, and stays closed', (tester) async {
    final device = await _pump(tester);

    await _rightClick(tester, _text('WALLET 2'));
    await tester.tap(find.descendant(of: _menu, matching: find.text('Rename…')));
    await tester.pumpAndSettle();
    await tester.tap(_field);
    await tester.pump();
    expect(_row('Trading'), findsNothing, reason: 'a click in the field is not a click on the heading');

    await tester.enterText(_field, 'Trading desk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(device.storage.names[2], 'Trading desk');
    expect(_text('TRADING DESK'), findsOneWidget);
    expect(_row('Trading'), findsNothing);
  });

  testOnMac('a failure under a heading stays with its wallet when a wallet above it opens', (tester) async {
    final device = await _pump(tester);
    device.storage.writeError = StateError('disk full');
    await _rightClick(tester, _text('WALLET 3'));
    await tester.tap(find.descendant(of: _menu, matching: find.text('Rename…')));
    await tester.pumpAndSettle();
    await tester.enterText(_field, 'Holidays');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await _click(tester, 'WALLET 2');

    final note = tester.getTopLeft(_text("Couldn't rename the wallet")).dy;
    expect(note, greaterThan(tester.getTopLeft(_text('WALLET 3')).dy));
    expect(note, lessThan(tester.getTopLeft(_text('COLD WALLET')).dy));
    await tester.pump(AccountNoteNotifier.failureShownFor);
  });

  testOnMac('a heading takes the keyboard\'s focus; Space and Return open and close it', (tester) async {
    await _pump(tester);
    final node = Focus.of(tester.element(_text('WALLET 2')));
    expect(node.canRequestFocus, isTrue);
    expect(node.skipTraversal, isFalse);

    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_row('Trading'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_row('Trading'), findsNothing);
  });

  testOnMac('a screen reader hears a heading\'s name, whether it is open, and how many accounts a closed one holds', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Wallet 2')),
      isSemantics(
        label: 'Wallet 2',
        value: '2 accounts, ${_tokens(tester, 2)}',
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Cold Wallet')),
      isSemantics(label: 'Cold Wallet', value: '1 account, ${_tokens(tester, 1)}', isButton: true, isExpanded: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wallet 1')),
      isSemantics(label: 'Wallet 1', isButton: false, hasExpandedState: true, isExpanded: true),
    );

    await _click(tester, 'WALLET 2');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Wallet 2')),
      isSemantics(label: 'Wallet 2', isButton: true, hasExpandedState: true, isExpanded: true),
    );
    semantics.dispose();
  });

  testOnMac('the multisigs sit closed under their own heading with their count; a click opens them, and closes them', (
    tester,
  ) async {
    await _pump(tester, multisigs: [teamMultisig, orphanMultisig]);

    expect(_row('Team'), findsNothing);
    expect(_row('Orphan'), findsNothing);
    expect(_chevron('MULTISIGS', CupertinoIcons.chevron_right), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: _text('MULTISIGS'), matching: find.byType(Row)).first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await _click(tester, 'MULTISIGS');
    expect(_row('Orphan'), findsOneWidget);
    expect(_row('Team'), findsOneWidget);
    expect(_chevron('MULTISIGS', CupertinoIcons.chevron_down), findsOneWidget);

    await _click(tester, 'MULTISIGS');
    expect(_row('Team'), findsNothing);
  });

  testOnMac('a wallet\'s count leaves out the multisigs its accounts are members of', (tester) async {
    await _pump(
      tester,
      multisigs: [
        MultisigAccount(
          name: 'Desk',
          accountId: 'qzDesk',
          signers: const ['qzTrading', 'qzOther'],
          threshold: 2,
          nonce: BigInt.zero,
          myMemberAccountId: 'qzTrading',
        ),
      ],
    );

    expect(
      find.descendant(
        of: find.ancestor(of: _text('WALLET 2'), matching: find.byType(Row)).first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await _click(tester, 'WALLET 2');
    expect(_row('Desk'), findsNothing, reason: 'it is under MULTISIGS');
  });

  testOnMac('a multisig being active holds its group open with no chevron; its member\'s wallet can close', (
    tester,
  ) async {
    await _pump(tester, multisigs: [teamMultisig]);

    await _choose(tester, 'Account', 'Team');

    expect(_selected(tester), 'Team');
    expect(_chevron('MULTISIGS', CupertinoIcons.chevron_down), findsNothing);
    expect(_chevron('MULTISIGS', CupertinoIcons.chevron_right), findsNothing);
    await _click(tester, 'MULTISIGS');
    expect(_row('Team'), findsOneWidget);

    expect(_chevron('WALLET 1', CupertinoIcons.chevron_down), findsOneWidget, reason: 'kept open when left');
    await _click(tester, 'WALLET 1');
    expect(_row('Main'), findsNothing);
  });

  testOnMac('Next and Previous Sidebar Item step through the multisigs after the wallets while they are open', (
    tester,
  ) async {
    await _pump(tester, multisigs: [teamMultisig, orphanMultisig]);

    await _choose(tester, 'View', 'Previous Sidebar Item');
    expect(_selected(tester), 'Encrypted Account', reason: 'the multisigs are closed');

    await _click(tester, 'MULTISIGS');
    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Orphan');
    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Team');
    await _choose(tester, 'View', 'Next Sidebar Item');
    expect(_selected(tester), 'Main');
    await _choose(tester, 'View', 'Previous Sidebar Item');
    expect(_selected(tester), 'Team');
  });

  testOnMac('the multisigs take the ⌘ numbers after the wallets\' accounts', (tester) async {
    await _pump(tester, multisigs: [teamMultisig]);
    SingleActivator? shortcutOf(String name) =>
        _itemsOf(tester, 'Account').singleWhere((item) => item.label == name).shortcut as SingleActivator?;

    expect(shortcutOf('Main')?.trigger, LogicalKeyboardKey.digit1);
    expect(shortcutOf('Savings')?.trigger, LogicalKeyboardKey.digit2);
    expect(shortcutOf('Vault')?.trigger, LogicalKeyboardKey.digit8);
    expect(shortcutOf('Team')?.trigger, LogicalKeyboardKey.digit9);
  });

  testOnMac('the multisigs\' heading takes the keyboard\'s focus; Space and Return open and close it', (tester) async {
    await _pump(tester, multisigs: [teamMultisig]);
    final node = Focus.of(tester.element(_text('MULTISIGS')));
    expect(node.canRequestFocus, isTrue);
    expect(node.skipTraversal, isFalse);

    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_row('Team'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_row('Team'), findsNothing);
  });

  testOnMac('a screen reader hears the multisigs\' heading, whether it is open, and how many a closed one holds', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, multisigs: [teamMultisig, orphanMultisig]);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Multisigs')),
      isSemantics(
        label: 'Multisigs',
        value: '2 accounts, ${_tokens(tester, 2)}',
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );

    await _click(tester, 'MULTISIGS');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Multisigs')),
      isSemantics(label: 'Multisigs', isButton: true, hasExpandedState: true, isExpanded: true),
    );
    semantics.dispose();
  });

  group('a closed group\'s total', () {
    testOnMac('a closed wallet shows its total under its name; the open one shows none', (tester) async {
      await _pump(tester);

      expect(_under('sidebar-wallet-2', _tokens(tester, 2)), findsOneWidget, reason: 'Trading and its Encrypted');
      expect(_under('sidebar-wallet-1', _tokens(tester, 1)), findsOneWidget, reason: 'the Cold Wallet holds Vault');
      expect(
        tester.getTopLeft(_under('sidebar-wallet-2', _tokens(tester, 2))).dy,
        greaterThan(tester.getBottomLeft(_text('WALLET 2')).dy),
        reason: 'on a line of its own under the name',
      );
      for (final amount in [1, 2, 3]) {
        expect(_under('sidebar-wallet-0', _tokens(tester, amount)), findsNothing, reason: 'Wallet 1 is open');
      }
    });

    testOnMac('opening a wallet hides its total; closing it shows the total again', (tester) async {
      await _pump(tester);

      await _click(tester, 'WALLET 2');
      expect(_under('sidebar-wallet-2', _tokens(tester, 2)), findsNothing);

      await _click(tester, 'WALLET 2');
      expect(_under('sidebar-wallet-2', _tokens(tester, 2)), findsOneWidget);
    });

    testOnMac('a wallet\'s total leaves out the multisigs its accounts are members of', (tester) async {
      await _pump(
        tester,
        multisigs: [
          MultisigAccount(
            name: 'Desk',
            accountId: 'qzDesk',
            signers: const ['qzTrading', 'qzOther'],
            threshold: 2,
            nonce: BigInt.zero,
            myMemberAccountId: 'qzTrading',
          ),
        ],
      );

      expect(_under('sidebar-wallet-2', _tokens(tester, 2)), findsOneWidget);
    });

    testOnMac('the closed multisigs\' heading shows the sum of its multisigs, and none while open', (tester) async {
      await _pump(tester, multisigs: [teamMultisig, orphanMultisig]);

      expect(_under('sidebar-multisigs', _tokens(tester, 2)), findsOneWidget);

      await _click(tester, 'MULTISIGS');
      expect(_under('sidebar-multisigs', _tokens(tester, 2)), findsNothing);
    });

    testOnMac('a closed heading says so while any of its balances loads', (tester) async {
      final never = Completer<BigInt>();
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, tradingAccount, _travel],
          settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
          balanceOf: (accountId) => accountId == 'qzTrading' ? never.future : Future.value(oneToken),
        ),
      );

      expect(_under('sidebar-wallet-2', 'Loading...'), findsOneWidget);
      expect(_under('sidebar-wallet-3', _tokens(tester, 1)), findsOneWidget);
    });

    testOnMac('a closed heading says the balance is unavailable when any of its balances fails', (tester) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, tradingAccount, _travel],
          settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
          balances: {'qzMain': oneToken, 'qzTravel': oneToken},
        ),
      );

      expect(_under('sidebar-wallet-2', 'Balance unavailable'), findsOneWidget);
      expect(_under('sidebar-wallet-3', _tokens(tester, 1)), findsOneWidget);
    });
  });

  group('moving a group', () {
    const headings = ['WALLET 1', 'WALLET 2', 'WALLET 3', 'COLD WALLET', 'MULTISIGS'];

    /// The groups' headings shown, top to bottom.
    List<String> order(WidgetTester tester) {
      final shown = [
        for (final heading in headings)
          if (_text(heading).evaluate().isNotEmpty) heading,
      ];
      return shown..sort((a, b) => tester.getTopLeft(_text(a)).dy.compareTo(tester.getTopLeft(_text(b)).dy));
    }

    MenuPanelRow item(WidgetTester tester, String label) =>
        tester.widget<MenuPanelRow>(find.descendant(of: _menu, matching: find.widgetWithText(MenuPanelRow, label)));

    Future<void> chooseInMenu(WidgetTester tester, String heading, String label) async {
      await _rightClick(tester, _text(heading));
      await tester.tap(find.descendant(of: _menu, matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

    testOnMac('each heading\'s menu offers Move Up and Move Down, the top one not up, the bottom one not down', (
      tester,
    ) async {
      await _pump(tester, multisigs: [teamMultisig]);
      expect(order(tester), ['WALLET 1', 'WALLET 2', 'WALLET 3', 'COLD WALLET', 'MULTISIGS']);

      await _rightClick(tester, _text('WALLET 1'));
      expect(item(tester, 'Move Up').isDisabled, isTrue);
      expect(item(tester, 'Move Down').isDisabled, isFalse);
      expect(find.descendant(of: _menu, matching: find.text('Rename…')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _rightClick(tester, _text('COLD WALLET'));
      expect(item(tester, 'Move Up').isDisabled, isFalse);
      expect(item(tester, 'Move Down').isDisabled, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _rightClick(tester, _text('MULTISIGS'));
      expect(item(tester, 'Move Up').isDisabled, isFalse);
      expect(item(tester, 'Move Down').isDisabled, isTrue);
      expect(find.descendant(of: _menu, matching: find.text('Create Multisig…')), findsOneWidget);
    });

    testOnMac('Move Down puts a wallet under the next one, its rows with it', (tester) async {
      await _pump(tester);

      await chooseInMenu(tester, 'WALLET 1', 'Move Down');

      expect(order(tester), ['WALLET 2', 'WALLET 1', 'WALLET 3', 'COLD WALLET']);
      expect(top(tester, _row('Main')), greaterThan(top(tester, _text('WALLET 1'))));
      expect(top(tester, _row('Savings')), lessThan(top(tester, _text('WALLET 3'))));
    });

    testOnMac('the multisigs\' heading moves the whole group', (tester) async {
      await _pump(tester, multisigs: [teamMultisig]);
      await _click(tester, 'MULTISIGS');

      await chooseInMenu(tester, 'MULTISIGS', 'Move Up');
      await chooseInMenu(tester, 'MULTISIGS', 'Move Up');

      expect(order(tester), ['WALLET 1', 'WALLET 2', 'MULTISIGS', 'WALLET 3', 'COLD WALLET']);
      expect(top(tester, _row('Team')), greaterThan(top(tester, _text('MULTISIGS'))));
      expect(top(tester, _row('Team')), lessThan(top(tester, _text('WALLET 3'))));
    });

    testOnMac('a heading dragged onto another group lands there, a line showing where while it is dragged', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(Sidebar.dropLineKey), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(_text('COLD WALLET')),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      final target = tester.getTopLeft(_text('WALLET 1')) + const Offset(4, 1);
      for (var step = 1; step <= 10; step++) {
        await gesture.moveTo(Offset.lerp(tester.getCenter(_text('COLD WALLET')), target, step / 10)!);
        await tester.pump();
      }
      expect(find.byKey(Sidebar.dropLineKey), findsOneWidget);
      expect(top(tester, find.byKey(Sidebar.dropLineKey)), lessThan(top(tester, _text('WALLET 1'))));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(Sidebar.dropLineKey), findsNothing);
      expect(order(tester), ['COLD WALLET', 'WALLET 1', 'WALLET 2', 'WALLET 3']);
    });

    testOnMac('a click on a heading still opens and closes it; a heading being renamed is not dragged', (tester) async {
      await _pump(tester);
      await _click(tester, 'WALLET 2');
      expect(_row('Trading'), findsOneWidget);
      await _click(tester, 'WALLET 2');
      expect(_row('Trading'), findsNothing);

      await chooseInMenu(tester, 'WALLET 3', 'Rename…');
      expect(_field, findsOneWidget);
      final from = tester.getCenter(_field);
      final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
      for (var step = 1; step <= 10; step++) {
        await gesture.moveTo(from - Offset(0, 12.0 * step));
        await tester.pump();
      }
      expect(find.byKey(Sidebar.dropLineKey), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(order(tester).where((heading) => heading != 'WALLET 3'), ['WALLET 1', 'WALLET 2', 'COLD WALLET']);
      expect(_field, findsOneWidget);
    });

    testOnMac('after a move, ⌘1 is the top account and the Account menu lists them in the new order', (tester) async {
      await _pump(tester);

      await chooseInMenu(tester, 'WALLET 1', 'Move Down');

      final accounts = [
        for (final item in _itemsOf(tester, 'Account'))
          if (['Main', 'Savings', 'Trading', 'Travel', 'Vault'].contains(item.label)) item,
      ];
      expect([for (final item in accounts) item.label], ['Trading', 'Main', 'Savings', 'Travel', 'Vault']);
      expect((accounts.first.shortcut as SingleActivator?)?.trigger, LogicalKeyboardKey.digit1);
    });

    testOnMac('Next and Previous Sidebar Item follow the new order', (tester) async {
      await _pump(tester);
      await chooseInMenu(tester, 'WALLET 1', 'Move Down');
      await _click(tester, 'WALLET 2');

      await _choose(tester, 'View', 'Previous Sidebar Item');
      await _choose(tester, 'View', 'Previous Sidebar Item');

      expect(_selected(tester), 'Trading');
    });
  });
}
