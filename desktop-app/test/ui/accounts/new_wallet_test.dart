import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

/// The address the fake key derivation gives the phrase New Wallet generates.
const _rootId = 'qz(fresh)';

/// Main (active) and Savings in Wallet 1, Vault in the Cold Wallet, and
/// Trading in Wallet 2, at wallet index 2: a wallet made here takes index 3.
/// Each recovery phrase generated starts with "fresh", then "second", "third".
Future<FakeWalletDevice> _pump(WidgetTester tester) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll([vaultAccount, tradingAccount]);
  device.storage.mnemonics[2] = 'trading words';
  final firstWords = ['fresh', 'second', 'third'];
  var made = 0;
  device.generateMnemonic = () async => '${firstWords[made++]} wallet recovery phrase';
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

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder get _addRow => _inSidebar(find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

/// The name field open in the sidebar: a wallet's heading being named.
Finder get _headingField => _inSidebar(find.byType(EditableText));

String? _activeId(WidgetTester tester) => _container(tester).read(activeAccountProvider).value?.account.accountId;

/// The Account menu's groups in the menu bar.
List<PlatformMenuItemGroup> _accountGroups(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return menus.singleWhere((menu) => menu.label == 'Account').menus.cast<PlatformMenuItemGroup>();
}

/// The Account menu's New Wallet.
PlatformMenuItem _menuBarItem(WidgetTester tester) =>
    [for (final group in _accountGroups(tester)) ...group.members].singleWhere((item) => item.label == 'New Wallet');

/// Chooses New Wallet in the sidebar's Add Account menu.
Future<void> _chooseInSidebar(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('New Wallet')));
  await tester.pumpAndSettle();
}

void main() {
  group('where New Wallet is offered', () {
    testOnMac('the Add Account menu has it above Import Wallet…', (tester) async {
      await _pump(tester);

      await tester.tap(_addRow);
      await tester.pumpAndSettle();

      final labels = [
        for (final row in tester.widgetList<MenuPanelRow>(
          find.descendant(of: _menu, matching: find.byType(MenuPanelRow)),
        ))
          row.label,
      ];
      expect(labels, [
        'New Account',
        'New Wallet',
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
      // After New Account's separator, in Import Wallet…'s group.
      final firstSeparator = find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)).first;
      final newWallet = find.descendant(of: _menu, matching: find.text('New Wallet'));
      expect(tester.getTopLeft(firstSeparator).dy, lessThan(tester.getTopLeft(newWallet).dy));
      expect(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)), findsNWidgets(2));
    });

    testOnMac('the Account menu has it above Import Wallet…, with no shortcut', (tester) async {
      await _pump(tester);

      final groups = _accountGroups(tester);
      final group = groups.singleWhere((group) => group.members.any((item) => item.label == 'New Wallet'));

      expect(group.members.map((item) => item.label), ['New Wallet', 'Import Wallet…', 'Connect Cold Wallet…']);
      expect(_menuBarItem(tester).shortcut, isNull);
    });

    testOnMac('the menu bar item is disabled while a sheet is open', (tester) async {
      await _pump(tester);
      expect(_menuBarItem(tester).onSelected, isNotNull);

      await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(_menuBarItem(tester).onSelected, isNull);
    });
  });

  group('New Wallet', () {
    testOnMac('adds a wallet at the next free index: a new phrase, its first account and its Encrypted account, made '
        'on this device', (tester) async {
      final device = await _pump(tester);
      final before = device.storage.accounts.length;

      await _chooseInSidebar(tester);

      expect(device.storage.mnemonics[3], 'fresh wallet recovery phrase');
      final root = device.storage.accounts.singleWhere((a) => a.accountId == _rootId);
      expect(root.walletIndex, 3);
      expect(root.index, 0);
      expect(root.accountType, AccountType.local);
      expect(
        device.storage.accounts.where((a) => a.walletIndex == 3 && a.accountType == AccountType.encrypted),
        hasLength(1),
      );
      expect(device.storage.accounts, hasLength(before + 2));
      expect(device.storage.origins[3], WalletOrigin.created);
    });

    testOnMac('its first account is active, its group open, and its heading ready to be named', (tester) async {
      final device = await _pump(tester);

      await _chooseInSidebar(tester);

      expect(_activeId(tester), _rootId);
      expect(device.storage.activeAccount?.account.accountId, _rootId);
      final root = device.storage.accounts.singleWhere((a) => a.accountId == _rootId);
      expect(_inSidebar(find.widgetWithText(SidebarRow, root.name)), findsOneWidget);
      final field = tester.widget<EditableText>(_headingField);
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.text, 'Wallet 3');
      expect(field.controller.selection.textInside(field.controller.text), 'Wallet 3');
    });

    testOnMac('the menu bar\'s item does the same', (tester) async {
      final device = await _pump(tester);

      _menuBarItem(tester).onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.accounts.singleWhere((a) => a.accountId == _rootId).walletIndex, 3);
      expect(_activeId(tester), _rootId);
      expect(_headingField, findsOneWidget);
    });

    testOnMac('with the sidebar hidden nothing opens to rename, and the top bar says it was created', (tester) async {
      final device = await _pump(tester);
      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      _menuBarItem(tester).onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.accounts.map((a) => a.accountId), contains(_rootId));
      expect(_activeId(tester), _rootId);
      expect(_container(tester).read(sidebarRenameProvider), isNull);
      expect(_container(tester).read(shellSheetProvider), isNull);
      expect(find.descendant(of: find.byType(ShellTopBar), matching: find.text('Wallet created')), findsOneWidget);
    });

    testOnMac('two chosen before the first is made give two wallets, at different indexes', (tester) async {
      final device = await _pump(tester);

      final item = _menuBarItem(tester);
      item.onSelected!();
      item.onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qz(fresh)').walletIndex, 3);
      expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qz(second)').walletIndex, 4);
      expect(device.storage.mnemonics.keys, containsAll([3, 4]));
      expect(_activeId(tester), 'qz(second)');
    });

    testOnMac('chosen while a sheet is open, it makes nothing', (tester) async {
      final device = await _pump(tester);
      final before = device.storage.accounts.length;
      final item = _menuBarItem(tester);
      await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      item.onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.accounts, hasLength(before));
      expect(device.storage.mnemonics.containsKey(3), isFalse);
    });

    testOnMac('a wallet that cannot be stored says so on the active account, and nothing is added', (tester) async {
      final device = await _pump(tester);
      final before = device.storage.accounts.length;
      device.storage.mnemonicWriteError = StateError('the keychain is locked');

      await _chooseInSidebar(tester);

      expect(_inSidebar(find.text('Couldn’t create the wallet')), findsOneWidget);
      expect(device.storage.accounts, hasLength(before));
      expect(device.storage.mnemonics.containsKey(3), isFalse);
      expect(_activeId(tester), mainAccount.accountId);
      expect(_headingField, findsNothing);
    });

    testOnMac('a wallet made where one was removed starts with none of what the old one kept', (tester) async {
      final device = await _pump(tester);
      final manager = _container(tester).read(accountManagerProvider);
      await manager.renameWallet(2, 'Old Trading');
      await tester.pumpAndSettle();
      expect(_inSidebar(find.text('OLD TRADING')), findsOneWidget);
      await manager.disconnect(tradingAccount);
      await tester.pumpAndSettle();

      await _chooseInSidebar(tester);

      expect(device.storage.accounts.singleWhere((a) => a.accountId == _rootId).walletIndex, 2);
      expect(_container(tester).read(walletNameProvider(2)), isNull);
      expect(tester.widget<EditableText>(_headingField).controller.text, 'Wallet 2');
    });
  });
}
