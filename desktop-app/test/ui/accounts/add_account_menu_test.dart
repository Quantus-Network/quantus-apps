import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

const _travel = Account(walletIndex: 3, index: 0, name: 'Travel', accountId: 'qzTravel');

/// Main (active unless [active] says) and Savings in Wallet 1, and Vault in the
/// Cold Wallet; with [severalWallets], Trading in Wallet 2 and Travel in
/// Wallet 3 as well.
Future<FakeWalletDevice> _pump(WidgetTester tester, {bool severalWallets = true, Account? active}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.add(vaultAccount);
  if (severalWallets) {
    device.storage.accounts.addAll([tradingAccount, _travel]);
    device.storage.mnemonics[2] = 'trading words';
    device.storage.mnemonics[3] = 'travel words';
  }
  if (active != null) device.storage.activeAccount = RegularAccount(active);
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

Finder get _submenu => find.byKey(ContextMenuRegion.submenuKey);

Finder get _field => _inSidebar(find.byType(EditableText));

List<String> _labels(WidgetTester tester, Finder panel) => [
  for (final row in tester.widgetList<MenuPanelRow>(find.descendant(of: panel, matching: find.byType(MenuPanelRow))))
    row.label,
];

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
}

Future<void> _openSubmenu(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.descendant(of: _menu, matching: find.text('New Account')));
  await tester.pumpAndSettle();
}

/// The Account menu's New Account: an item, or the submenu it opens.
PlatformMenuItem _newAccount(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  final items = [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
  return items.singleWhere((item) => item.label == 'New Account');
}

List<PlatformMenuItem> _submenuItems(WidgetTester tester) => (_newAccount(tester) as PlatformMenu).menus;

Future<void> _pressWithCommand(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  for (final key in keys) {
    await tester.sendKeyEvent(key);
  }
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

String? _activeId(WidgetTester tester) => _container(tester).read(activeAccountProvider).value?.account.accountId;

/// Leaves a switch to [account] waiting in the navigation queue, as while it
/// is being saved. The function returned lets it run.
Future<void> Function() _holdSwitchTo(WidgetTester tester, Account account) {
  final container = _container(tester);
  final gate = Completer<void>();
  unawaited(container.read(shellNavigationProvider.notifier).run(() => gate.future));
  unawaited(container.read(sidebarSelectionProvider.notifier).showAccount(RegularAccount(account)));
  return () async {
    gate.complete();
    await tester.pumpAndSettle();
  };
}

void main() {
  group('the Add Account menu', () {
    testOnMac('with one software wallet it opens above the row, with a plain New Account', (tester) async {
      await _pump(tester, severalWallets: false);

      await _openMenu(tester);

      expect(_labels(tester, _menu), [
        'New Account',
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
      expect(find.descendant(of: _menu, matching: find.byIcon(CupertinoIcons.chevron_right)), findsNothing);
      expect(tester.getBottomLeft(_menu).dy, lessThanOrEqualTo(tester.getTopLeft(_addRow).dy));
      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('New Account adds the account, active, with its name ready to be typed over', (tester) async {
      final device = await _pump(tester, severalWallets: false);

      await _openMenu(tester);
      await tester.tap(find.descendant(of: _menu, matching: find.text('New Account')));
      await tester.pumpAndSettle();

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew0-2'));
      expect(_activeId(tester), 'qzNew0-2');
      final field = tester.widget<EditableText>(_field);
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.selection.textInside(field.controller.text), field.controller.text);
      expect(field.controller.text, startsWith('Account '));
    });

    testOnMac('with several, New Account opens the software wallets in the sidebar\'s order', (tester) async {
      await _pump(tester);

      await _openSubmenu(tester);

      expect(_labels(tester, _submenu), ['Wallet 1', 'Wallet 2', 'Wallet 3']);
    });

    testOnMac('choosing a closed wallet adds the account there and opens it', (tester) async {
      final device = await _pump(tester);
      expect(_inSidebar(find.widgetWithText(SidebarRow, 'Trading')), findsNothing);

      await _openSubmenu(tester);
      await tester.tap(find.descendant(of: _submenu, matching: find.text('Wallet 2')));
      await tester.pumpAndSettle();

      expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qzNew2-1').walletIndex, 2);
      expect(_activeId(tester), 'qzNew2-1');
      expect(_inSidebar(find.widgetWithText(SidebarRow, 'Trading')), findsOneWidget);
      expect(_field, findsOneWidget);
    });

    testOnMac('the keyboard reaches a wallet through it', (tester) async {
      final device = await _pump(tester);
      await _openMenu(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew3-1'));
    });
  });

  group('the menu bar', () {
    testOnMac('with one software wallet, New Account is a plain item with ⌘N', (tester) async {
      await _pump(tester, severalWallets: false);

      final item = _newAccount(tester);

      expect(item, isNot(isA<PlatformMenu>()));
      expect((item.shortcut! as SingleActivator).trigger, LogicalKeyboardKey.keyN);
    });

    testOnMac('with several, New Account is a submenu, ⌘N on the active account\'s wallet', (tester) async {
      await _pump(tester);

      final items = _submenuItems(tester);

      expect(items.map((item) => item.label), ['Wallet 1', 'Wallet 2', 'Wallet 3']);
      expect((items[0].shortcut! as SingleActivator).trigger, LogicalKeyboardKey.keyN);
      expect(items[1].shortcut, isNull);
      expect(items[2].shortcut, isNull);
    });

    testOnMac('a wallet chosen in the submenu gets the account', (tester) async {
      final device = await _pump(tester);

      _submenuItems(tester)[2].onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew3-1'));
    });

    testOnMac('⌘N adds the account to the active account\'s wallet', (tester) async {
      final device = await _pump(tester);

      await _pressWithCommand(tester, [LogicalKeyboardKey.keyN]);

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew0-2'));
    });

    testOnMac('with a Cold Wallet account active, no wallet has ⌘N and the key does nothing', (tester) async {
      final device = await _pump(tester, active: vaultAccount);
      final before = device.storage.accounts.length;

      expect(_submenuItems(tester).map((item) => item.shortcut), everyElement(isNull));
      await _pressWithCommand(tester, [LogicalKeyboardKey.keyN]);

      expect(device.storage.accounts, hasLength(before));
    });

    testOnMac('from a Cold Wallet account, ⌘1 then ⌘N before the next frame adds to the wallet switched to', (
      tester,
    ) async {
      final device = await _pump(tester, active: vaultAccount);

      await _pressWithCommand(tester, [LogicalKeyboardKey.digit1, LogicalKeyboardKey.keyN]);

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew0-2'));
    });

    group('during a switch to another wallet', () {
      testOnMac('the wallet chosen in the menu bar gets the account, even the one showing ⌘N', (tester) async {
        final device = await _pump(tester);
        final release = _holdSwitchTo(tester, tradingAccount);

        final chosen = _submenuItems(tester)[0];
        expect(chosen.shortcut, isNotNull);
        chosen.onSelected!();
        await release();

        expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qzNew0-2').walletIndex, 0);
      });

      testOnMac('the wallet chosen in the sidebar\'s menu gets the account', (tester) async {
        final device = await _pump(tester);
        await _openSubmenu(tester);
        final release = _holdSwitchTo(tester, tradingAccount);

        await tester.tap(find.descendant(of: _submenu, matching: find.text('Wallet 1')));
        await tester.pump();
        await release();

        expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qzNew0-2').walletIndex, 0);
      });

      testOnMac('⌘N adds to the wallet switched to', (tester) async {
        final device = await _pump(tester);
        final release = _holdSwitchTo(tester, tradingAccount);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await release();

        expect(device.storage.accounts.singleWhere((a) => a.accountId == 'qzNew2-1').walletIndex, 2);
      });
    });

    testOnMac('while a sheet is open, New Account is disabled', (tester) async {
      await _pump(tester);
      await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(_submenuItems(tester).map((item) => item.onSelected), everyElement(isNull));
    });

    testOnMac('with the sidebar hidden, New Account opens Get Info on the name', (tester) async {
      await _pump(tester);
      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      _submenuItems(tester)[1].onSelected!();
      await tester.pumpAndSettle();

      final field = find.descendant(of: find.byKey(AccountInfoSheet.nameFieldKey), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    });

    testOnWindowsAndLinux('the bar in the window draws the submenu, and Ctrl+N adds the account', (tester) async {
      final device = await _pump(tester);

      await tester.tap(find.widgetWithText(SubmenuButton, 'Account'));
      await tester.pumpAndSettle();
      expect(find.text('New Account'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew0-2'));
    });

    testOnMac('Settings › Keyboard Shortcuts calls it New Account', (tester) async {
      await _pump(tester);
      await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsSheet.keyboardShortcutsRowKey));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ShellSheetView), matching: find.text('New Account')), findsOneWidget);
    });

    testOnMac('a changed shortcut for it keeps working', (tester) async {
      final device = await _pump(tester);
      await _container(tester)
          .read(shortcutBindingsProvider.notifier)
          .setShortcut(AppCommand.addAccount, const KeyCombo(LogicalKeyboardKey.keyJ, KeyModifiers(meta: true)));
      await tester.pumpAndSettle();

      await _pressWithCommand(tester, [LogicalKeyboardKey.keyJ]);

      expect(device.storage.accounts.map((a) => a.accountId), contains('qzNew0-2'));
    });
  });
}
