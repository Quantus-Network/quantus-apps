import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

/// The native menus the macOS app hands to the system.
List<PlatformMenu> _nativeMenus(WidgetTester tester) =>
    tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();

PlatformMenu _nativeMenu(WidgetTester tester, String label) =>
    _nativeMenus(tester).singleWhere((menu) => menu.label == label);

/// A menu's items in order, with its groups opened up.
List<PlatformMenuItem> _itemsOf(PlatformMenu menu) => [
  for (final entry in menu.menus)
    if (entry is PlatformMenuItemGroup) ...entry.members else entry,
];

PlatformMenuItem _nativeItem(WidgetTester tester, String menu, String label) =>
    _itemsOf(_nativeMenu(tester, menu)).singleWhere((item) => item.label == label);

List<PlatformProvidedMenuItemType> _providedTypes(PlatformMenu menu) => [
  for (final item in _itemsOf(menu))
    if (item is PlatformProvidedMenuItem) item.type,
];

/// Matches a shortcut of [key] with exactly these modifiers held.
/// [SingleActivator] has no value equality, so its parts are compared.
Matcher _isShortcut(LogicalKeyboardKey key, {bool meta = false, bool control = false, bool shift = false}) {
  return isA<SingleActivator>()
      .having((shortcut) => shortcut.trigger, 'trigger', key)
      .having((shortcut) => shortcut.meta, 'meta', meta)
      .having((shortcut) => shortcut.control, 'control', control)
      .having((shortcut) => shortcut.shift, 'shift', shift)
      .having((shortcut) => shortcut.alt, 'alt', false);
}

/// The Account menu's groups in order: the active account's actions (absent
/// when there is no active account), Add Account…, then the accounts.
List<List<PlatformMenuItem>> _accountMenuGroups(WidgetTester tester) => [
  for (final entry in _nativeMenu(tester, 'Account').menus) (entry as PlatformMenuItemGroup).members,
];

/// The Account menu's items that act on the active account or add one: all
/// of it but the list of accounts at its end.
List<PlatformMenuItem> _accountMenuActions(WidgetTester tester) {
  final groups = _accountMenuGroups(tester);
  return groups.take(groups.length - 1).expand((group) => group).toList();
}

/// The accounts the Account menu lists, at its end.
List<PlatformMenuItem> _accountMenuAccounts(WidgetTester tester) => _accountMenuGroups(tester).last;

const _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// The names of the sidebar's account rows, top to bottom.
List<String> _sidebarAccounts(WidgetTester tester) => [
  for (final row in tester.widgetList<SidebarRow>(
    find.descendant(of: find.byType(Sidebar), matching: find.byType(SidebarRow)),
  ))
    if (!row.isSecondary) row.title,
];

/// The title of the sidebar row that is selected.
String _selected(WidgetTester tester) => tester
    .widgetList<SidebarRow>(find.descendant(of: find.byType(Sidebar), matching: find.byType(SidebarRow)))
    .singleWhere((row) => row.isSelected)
    .title;

Finder _sheetTitled(String title) => find.descendant(of: find.byType(ShellSheetView), matching: find.text(title));

Finder _toolbarButton(String label) =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, label));

List<Override> _withActive(DisplayAccount active) => shellOverrides(
  accounts: const [mainAccount, vaultAccount],
  settings: FakeSettingsService(activeAccount: active, multisigs: [teamMultisig]),
  balances: oneTokenEach,
);

void main() {
  group('on macOS', () {
    testOnMac('the menu bar is native: nothing is drawn in the window', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(find.byType(PlatformMenuBar), findsOneWidget);
      expect(find.byType(MenuBar), findsNothing);
      expect(_nativeMenus(tester).map((menu) => menu.label), ['Quantus Wallet', 'File', 'Account', 'View', 'Window']);
    });

    testOnMac('the app menu has About, Settings…, Services, Hide, Hide Others, Show All and Quit', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      final appMenu = _nativeMenu(tester, 'Quantus Wallet');
      expect(_itemsOf(appMenu).map((item) => item is PlatformProvidedMenuItem ? item.type.name : item.label), [
        'about',
        'Settings…',
        'servicesSubmenu',
        'hide',
        'hideOtherApplications',
        'showAllApplications',
        'quit',
      ]);
      expect(
        _nativeItem(tester, 'Quantus Wallet', 'Settings…').shortcut,
        _isShortcut(LogicalKeyboardKey.comma, meta: true),
      );
    });

    testOnMac('the View and Window menus carry the system\'s full screen, minimize and zoom items', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_providedTypes(_nativeMenu(tester, 'View')), [PlatformProvidedMenuItemType.toggleFullScreen]);
      expect(_providedTypes(_nativeMenu(tester, 'Window')), [
        PlatformProvidedMenuItemType.minimizeWindow,
        PlatformProvidedMenuItemType.zoomWindow,
        PlatformProvidedMenuItemType.arrangeWindowsInFront,
      ]);
    });

    testOnMac('Settings… opens the Settings sheet', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Quantus Wallet', 'Settings…').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Settings'), findsOneWidget);
    });

    for (final (description, account, expected) in <(String, DisplayAccount, List<(String, bool)>)>[
      (
        'a local account',
        const RegularAccount(mainAccount),
        [('Receive', true), ('Send', true), ('Swap', true), ('Add Account…', true)],
      ),
      (
        // Its key signs on the hardware wallet, which this app cannot ask yet.
        'a Keystone account',
        const RegularAccount(vaultAccount),
        [('Receive', true), ('Send', false), ('Swap', false), ('Add Account…', true)],
      ),
      (
        'a multisig',
        MultisigDisplayAccount(teamMultisig),
        [('Receive', true), ('Propose', true), ('Add Account…', true)],
      ),
    ]) {
      testOnMac('the Account menu offers what the toolbar offers for $description', (tester) async {
        await pumpShell(tester, overrides: _withActive(account));

        final items = _accountMenuActions(tester);
        expect([for (final item in items) (item.label, item.onSelected != null)], expected);

        for (final (label, enabled) in expected.where((entry) => entry.$1 != 'Add Account…')) {
          expect(_toolbarButton(label), findsOneWidget, reason: label);
          expect(tester.widget<ToolbarAction>(_toolbarButton(label)).onPressed != null, enabled, reason: label);
        }
        expect(
          find.descendant(of: find.byType(AccountToolbar), matching: find.byType(ToolbarAction)),
          findsNWidgets(expected.length - 1),
        );
      });
    }

    testOnMac('an Account menu item opens the same sheet as its toolbar button', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Account', 'Send').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Send'), findsOneWidget);
    });

    testOnMac('with no active account the Account menu offers no actions: Add Account… and the accounts', (
      tester,
    ) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
      );

      expect(_itemsOf(_nativeMenu(tester, 'Account')).map((item) => item.label), ['Add Account…', 'Main']);
    });

    testOnMac('Receive, Send and Add Account… answer to ⌘R, ⌘S and ⌘N; Swap has no shortcut yet', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_nativeItem(tester, 'Account', 'Receive').shortcut, _isShortcut(LogicalKeyboardKey.keyR, meta: true));
      expect(_nativeItem(tester, 'Account', 'Send').shortcut, _isShortcut(LogicalKeyboardKey.keyS, meta: true));
      expect(_nativeItem(tester, 'Account', 'Add Account…').shortcut, _isShortcut(LogicalKeyboardKey.keyN, meta: true));
      expect(_nativeItem(tester, 'Account', 'Swap').shortcut, isNull);
    });

    testOnMac('the Account menu lists the accounts in the sidebar\'s order, numbered from ⌘1', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      final accounts = _accountMenuAccounts(tester);
      expect(accounts.map((item) => item.label), _sidebarAccounts(tester));
      expect(accounts.map((item) => item.label), ['Main', 'Team', 'Vault']);
      for (final (index, item) in accounts.indexed) {
        expect(item.shortcut, _isShortcut(_digits[index], meta: true), reason: item.label);
      }
    });

    testOnMac('accounts past the ninth are listed without a number', (tester) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: [
            for (var index = 0; index < 11; index++)
              Account(walletIndex: 0, index: index, name: 'Account ${index + 1}', accountId: 'qzAccount$index'),
          ],
          balances: oneTokenEach,
        ),
      );

      final accounts = _accountMenuAccounts(tester);
      expect(accounts.map((item) => item.label), _sidebarAccounts(tester));
      expect(accounts, hasLength(11));
      expect(accounts[8].shortcut, _isShortcut(LogicalKeyboardKey.digit9, meta: true));
      expect(accounts[9].shortcut, isNull);
      expect(accounts[10].shortcut, isNull);
    });

    testOnMac('choosing an account in the Account menu makes it the active account and shows it', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Mining Rewards')));
      await tester.pumpAndSettle();
      expect(find.byType(MiningRewardsPane), findsOneWidget);

      _accountMenuAccounts(tester).singleWhere((item) => item.label == 'Vault').onSelected!();
      await tester.pumpAndSettle();

      expect(_selected(tester), 'Vault');
      expect(find.byType(AccountPane), findsOneWidget);
      // Vault's key signs on its hardware wallet, so Send is offered dimmed.
      expect(_nativeItem(tester, 'Account', 'Send').onSelected, isNull);
    });

    testOnMac('View → Next and Previous Sidebar Item (⌃Tab, ⌃⇧Tab) walk the sidebar, Mining Rewards included, and '
        'go round at its ends', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(
        _nativeItem(tester, 'View', 'Next Sidebar Item').shortcut,
        _isShortcut(LogicalKeyboardKey.tab, control: true),
      );
      expect(
        _nativeItem(tester, 'View', 'Previous Sidebar Item').shortcut,
        _isShortcut(LogicalKeyboardKey.tab, control: true, shift: true),
      );

      Future<String> choose(String label) async {
        _nativeItem(tester, 'View', label).onSelected!();
        await tester.pumpAndSettle();
        return _selected(tester);
      }

      expect(_selected(tester), 'Main');
      expect(await choose('Next Sidebar Item'), 'Team');
      expect(await choose('Next Sidebar Item'), 'Vault');
      expect(await choose('Next Sidebar Item'), 'Mining Rewards');
      expect(find.byType(MiningRewardsPane), findsOneWidget);
      expect(await choose('Next Sidebar Item'), 'Main');
      expect(find.byType(AccountPane), findsOneWidget);
      expect(await choose('Previous Sidebar Item'), 'Mining Rewards');
      expect(await choose('Previous Sidebar Item'), 'Vault');
    });

    testOnMac('while a sheet is open, the items that open sheets are disabled', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Account', 'Add Account…').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Add Account'), findsOneWidget);
      expect(_nativeItem(tester, 'Quantus Wallet', 'Settings…').onSelected, isNull);
      // The accounts it lists among them: a sheet is for the account it opened on.
      expect(_itemsOf(_nativeMenu(tester, 'Account')).map((item) => item.label), contains('Vault'));
      for (final item in _itemsOf(_nativeMenu(tester, 'Account'))) {
        expect(item.onSelected, isNull, reason: item.label);
      }
      expect(_nativeItem(tester, 'View', 'Next Sidebar Item').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Previous Sidebar Item').onSelected, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_nativeItem(tester, 'Quantus Wallet', 'Settings…').onSelected, isNotNull);
    });

    testOnMac('View → Hide Sidebar hides the sidebar and becomes Show Sidebar, which brings it back', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      final hide = _nativeItem(tester, 'View', 'Hide Sidebar');
      expect(hide.shortcut, _isShortcut(LogicalKeyboardKey.keyB, meta: true));

      hide.onSelected!();
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);
      final show = _nativeItem(tester, 'View', 'Show Sidebar');
      expect(show.shortcut, _isShortcut(LogicalKeyboardKey.keyB, meta: true));

      show.onSelected!();
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsOneWidget);
      expect(_nativeItem(tester, 'View', 'Hide Sidebar'), isNotNull);
    });

    testOnMac('while there is no wallet the items that act on one are disabled; Close Window still works', (
      tester,
    ) async {
      var exitRequests = 0;
      await pumpShell(
        tester,
        overrides: [...FakeWalletDevice().overrides, requestAppExitProvider.overrideWithValue(() => exitRequests++)],
      );

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(_nativeItem(tester, 'Quantus Wallet', 'Settings…').onSelected, isNull);
      expect(_nativeItem(tester, 'Account', 'Add Account…').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Hide Sidebar').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Next Sidebar Item').onSelected, isNull);

      _nativeItem(tester, 'File', 'Close Window').onSelected!();

      expect(exitRequests, 1);
    });

    testOnMac('File → Close Window (⌘W) asks the app to exit', (tester) async {
      var exitRequests = 0;
      await pumpShell(
        tester,
        overrides: [
          ..._withActive(const RegularAccount(mainAccount)),
          requestAppExitProvider.overrideWithValue(() => exitRequests++),
        ],
      );

      final close = _nativeItem(tester, 'File', 'Close Window');
      expect(close.shortcut, _isShortcut(LogicalKeyboardKey.keyW, meta: true));

      close.onSelected!();

      expect(exitRequests, 1);
    });
  });

  group('on Windows and Linux', () {
    Future<void> openMenu(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(of: find.byType(MenuBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    testOnWindowsAndLinux('the menus are drawn in the window, without the macOS-only ones', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(find.byType(MenuBar), findsOneWidget);
      expect(
        tester
            .widgetList<SubmenuButton>(find.descendant(of: find.byType(MenuBar), matching: find.byType(SubmenuButton)))
            .map((button) => (button.child! as Text).data),
        ['Quantus Wallet', 'File', 'Account', 'View'],
      );
    });

    testOnWindowsAndLinux('the app menu holds Settings… with Ctrl+, and choosing it opens the Settings sheet', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await openMenu(tester, 'Quantus Wallet');

      final settings = find.widgetWithText(MenuItemButton, 'Settings…');
      expect(tester.widget<MenuItemButton>(settings).shortcut, _isShortcut(LogicalKeyboardKey.comma, control: true));
      expect(find.byType(MenuItemButton), findsOneWidget);

      await tester.tap(settings);
      await tester.pumpAndSettle();

      expect(_sheetTitled('Settings'), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+, opens the Settings sheet', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(_sheetTitled('Settings'), findsOneWidget);
    });

    testOnWindowsAndLinux('the Account menu lists the toolbar\'s actions, the disabled ones included', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(vaultAccount)));

      await openMenu(tester, 'Account');

      final items = tester.widgetList<MenuItemButton>(find.byType(MenuItemButton)).toList();
      expect(
        [for (final item in items) ((item.child! as Text).data, item.onPressed != null)],
        [
          ('Receive', true),
          ('Send', false),
          ('Swap', false),
          ('Add Account…', true),
          ('Main', true),
          ('Team', true),
          ('Vault', true),
        ],
      );
      expect(
        tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Team')).shortcut,
        _isShortcut(LogicalKeyboardKey.digit2, control: true),
      );
    });

    testOnWindowsAndLinux('View → Hide Sidebar, with Ctrl+B, hides the sidebar', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await openMenu(tester, 'View');
      final hide = find.widgetWithText(MenuItemButton, 'Hide Sidebar');
      expect(tester.widget<MenuItemButton>(hide).shortcut, _isShortcut(LogicalKeyboardKey.keyB, control: true));
      await tester.tap(hide);
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsNothing);

      await openMenu(tester, 'View');

      expect(find.widgetWithText(MenuItemButton, 'Show Sidebar'), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+B hides the sidebar and pressing it again brings it back', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      Future<void> pressCtrlB() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await pressCtrlB();

      expect(find.byType(Sidebar), findsNothing);

      await pressCtrlB();

      expect(find.byType(Sidebar), findsOneWidget);
    });

    testOnWindowsAndLinux('while there is no wallet the menus are shown, and Ctrl+B and Ctrl+, do nothing', (
      tester,
    ) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(find.byType(MenuBar), findsOneWidget);

      for (final key in [LogicalKeyboardKey.keyB, LogicalKeyboardKey.comma]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(ShellSheetView), findsNothing);

      await openMenu(tester, 'View');

      expect(tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Hide Sidebar')).onPressed, isNull);
    });

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testOnWindowsAndLinux('Ctrl+1 to Ctrl+9 make the account of that number in the sidebar active; a number past '
        'the last does nothing', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await press(tester, LogicalKeyboardKey.digit3);
      expect(_selected(tester), 'Vault');

      await press(tester, LogicalKeyboardKey.digit2);
      expect(_selected(tester), 'Team');

      await press(tester, LogicalKeyboardKey.digit4);
      await press(tester, LogicalKeyboardKey.digit9);
      expect(_selected(tester), 'Team');

      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Mining Rewards')));
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.digit1);

      expect(_selected(tester), 'Main');
      expect(find.byType(AccountPane), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+Tab and Ctrl+Shift+Tab walk the sidebar and go round at its ends', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await press(tester, LogicalKeyboardKey.tab, shift: true);
      expect(_selected(tester), 'Mining Rewards');

      await press(tester, LogicalKeyboardKey.tab);
      expect(_selected(tester), 'Main');

      await press(tester, LogicalKeyboardKey.tab);
      expect(_selected(tester), 'Team');
    });

    for (final (key, name, title) in [
      (LogicalKeyboardKey.keyR, 'Ctrl+R', 'Receive'),
      (LogicalKeyboardKey.keyS, 'Ctrl+S', 'Send'),
      (LogicalKeyboardKey.keyN, 'Ctrl+N', 'Add Account'),
    ]) {
      testOnWindowsAndLinux('$name opens $title', (tester) async {
        await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

        await press(tester, key);

        expect(_sheetTitled(title), findsOneWidget);
      });
    }

    testOnWindowsAndLinux('Ctrl+S does nothing on an account this app cannot send from', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(vaultAccount)));

      await press(tester, LogicalKeyboardKey.keyS);

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnWindowsAndLinux('while a sheet is open, the shortcuts that switch account or open a sheet do nothing', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      await press(tester, LogicalKeyboardKey.keyR);
      expect(_sheetTitled('Receive'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.digit3);
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.keyS);
      await press(tester, LogicalKeyboardKey.keyN);

      expect(_selected(tester), 'Main');
      expect(_sheetTitled('Receive'), findsOneWidget);
      expect(find.byType(ShellSheetView), findsOneWidget);
    });

    testOnWindowsAndLinux('Ctrl+W asks the app to exit', (tester) async {
      var exitRequests = 0;
      await pumpShell(
        tester,
        overrides: [
          ..._withActive(const RegularAccount(mainAccount)),
          requestAppExitProvider.overrideWithValue(() => exitRequests++),
        ],
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(exitRequests, 1);
    });
  });
}
