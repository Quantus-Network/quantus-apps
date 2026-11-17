import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
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
Matcher _isShortcut(LogicalKeyboardKey key, {bool meta = false, bool control = false}) {
  return isA<SingleActivator>()
      .having((shortcut) => shortcut.trigger, 'trigger', key)
      .having((shortcut) => shortcut.meta, 'meta', meta)
      .having((shortcut) => shortcut.control, 'control', control)
      .having((shortcut) => shortcut.shift, 'shift', false)
      .having((shortcut) => shortcut.alt, 'alt', false);
}

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

        final items = _itemsOf(_nativeMenu(tester, 'Account'));
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

    testOnMac('with no active account the Account menu offers only Add Account…', (tester) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
      );

      expect(_itemsOf(_nativeMenu(tester, 'Account')).map((item) => item.label), ['Add Account…']);
    });

    testOnMac('while a sheet is open, the items that open sheets are disabled', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Account', 'Add Account…').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Add Account'), findsOneWidget);
      expect(_nativeItem(tester, 'Quantus Wallet', 'Settings…').onSelected, isNull);
      for (final item in _itemsOf(_nativeMenu(tester, 'Account'))) {
        expect(item.onSelected, isNull, reason: item.label);
      }

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
        [('Receive', true), ('Send', false), ('Swap', false), ('Add Account…', true)],
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
