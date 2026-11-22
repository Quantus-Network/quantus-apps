import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
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
Matcher _isShortcut(
  LogicalKeyboardKey key, {
  bool meta = false,
  bool control = false,
  bool alt = false,
  bool shift = false,
}) {
  return isA<SingleActivator>()
      .having((shortcut) => shortcut.trigger, 'trigger', key)
      .having((shortcut) => shortcut.meta, 'meta', meta)
      .having((shortcut) => shortcut.control, 'control', control)
      .having((shortcut) => shortcut.shift, 'shift', shift)
      .having((shortcut) => shortcut.alt, 'alt', alt);
}

/// The Account menu's groups in order: the active account's actions (absent
/// when there is no active account), its own items (Get Info and the rest,
/// tested with the account menus), New Account, then the accounts.
List<List<PlatformMenuItem>> _accountMenuGroups(WidgetTester tester) => [
  for (final entry in _nativeMenu(tester, 'Account').menus) (entry as PlatformMenuItemGroup).members,
];

/// The Account menu's items that act on the active account or add one, as
/// the toolbar offers them: all of it but the account's own items and the
/// list of accounts at its end.
List<PlatformMenuItem> _accountMenuActions(WidgetTester tester) {
  final groups = _accountMenuGroups(tester);
  return groups
      .take(groups.length - 1)
      .where((group) => !group.any((item) => item.label == 'Get Info'))
      .expand((group) => group)
      .toList();
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
  settings: FakeSettingsService(activeAccount: active, multisigs: [teamMultisig], openWallets: const {0, 1}),
  balances: oneTokenEach,
);

/// Two accounts, Main and Savings, both of which send, stored on [settings].
List<Override> _withSlowSettings(SlowSettingsService settings) =>
    shellOverrides(accounts: const [mainAccount, savingsAccount], settings: settings, balances: oneTokenEach);

Finder _inSheet(Finder finder) => find.descendant(of: find.byType(ShellSheetView), matching: finder);

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
        [('Receive', true), ('Send', true), ('Swap', true), ('New Account', true), ('Import Wallet…', true)],
      ),
      (
        // Its key signs on the hardware wallet, which this app cannot ask yet.
        'a Keystone account',
        const RegularAccount(vaultAccount),
        [('Receive', true), ('Send', false), ('Swap', false), ('New Account', true), ('Import Wallet…', true)],
      ),
      (
        'a multisig',
        MultisigDisplayAccount(teamMultisig),
        [('Receive', true), ('Propose', true), ('New Account', true), ('Import Wallet…', true)],
      ),
    ]) {
      testOnMac('the Account menu offers what the toolbar offers for $description', (tester) async {
        await pumpShell(tester, overrides: _withActive(account));

        final items = _accountMenuActions(tester);
        expect([for (final item in items) (item.label, item.onSelected != null)], expected);

        final onToolbar = expected.where((entry) => entry.$1 != 'New Account' && entry.$1 != 'Import Wallet…');
        for (final (label, enabled) in onToolbar) {
          expect(_toolbarButton(label), findsOneWidget, reason: label);
          expect(tester.widget<ToolbarAction>(_toolbarButton(label)).onPressed != null, enabled, reason: label);
        }
        expect(
          find.descendant(of: find.byType(AccountToolbar), matching: find.byType(ToolbarAction)),
          findsNWidgets(onToolbar.length),
        );
      });
    }

    testOnMac('an Account menu item opens the same sheet as its toolbar button', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Account', 'Send').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Send'), findsOneWidget);
    });

    testOnMac('with no active account the Account menu offers no actions: adding one, and the accounts', (
      tester,
    ) async {
      await pumpShell(
        tester,
        overrides: shellOverrides(accounts: const [mainAccount], balances: oneTokenEach),
      );

      expect(_itemsOf(_nativeMenu(tester, 'Account')).map((item) => item.label), [
        'New Account',
        'Import Wallet…',
        'Main',
      ]);
    });

    testOnMac('Receive, Send and New Account answer to ⌘R, ⌘S and ⌘N; Swap has no shortcut yet', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(_nativeItem(tester, 'Account', 'Receive').shortcut, _isShortcut(LogicalKeyboardKey.keyR, meta: true));
      expect(_nativeItem(tester, 'Account', 'Send').shortcut, _isShortcut(LogicalKeyboardKey.keyS, meta: true));
      expect(_nativeItem(tester, 'Account', 'New Account').shortcut, _isShortcut(LogicalKeyboardKey.keyN, meta: true));
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
          settings: FakeSettingsService(openWallets: const {0}),
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

    testOnMac('while a switch is still being saved, Send is offered, to be checked against the account switched to', (
      tester,
    ) async {
      final settings = SlowSettingsService(activeAccount: const RegularAccount(vaultAccount));
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, vaultAccount],
          settings: settings,
          balances: oneTokenEach,
        ),
      );
      expect(_nativeItem(tester, 'Account', 'Send').onSelected, isNull);

      _accountMenuAccounts(tester).singleWhere((item) => item.label == 'Main').onSelected!();
      await tester.pumpAndSettle();
      final send = _nativeItem(tester, 'Account', 'Send');
      expect(send.onSelected, isNotNull);
      send.onSelected!();
      await tester.pumpAndSettle();
      await settings.finishWrites(tester);

      expect(find.byType(SendSheet), findsOneWidget);
      expect(_inSheet(find.text('Main')), findsOneWidget);
    });

    /// Presses [keys] one after another with ⌘ held, before any frame is
    /// drawn: the system's menus still hold what they did before the first.
    Future<void> pressWithCommand(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      for (final key in keys) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
    }

    testOnMac('⌘R, pressed, opens Receive: the app answers its shortcuts itself', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await pressWithCommand(tester, [LogicalKeyboardKey.keyR]);

      expect(_sheetTitled('Receive'), findsOneWidget);
    });

    testOnMac('⌘S, pressed on an account this app cannot send from, opens nothing', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(vaultAccount)));

      await pressWithCommand(tester, [LogicalKeyboardKey.keyS]);

      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('from an account that cannot send, ⌘1 then ⌘S before the next frame opens Send on the account '
        'switched to', (tester) async {
      final settings = SlowSettingsService(activeAccount: const RegularAccount(vaultAccount));
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, vaultAccount],
          settings: settings,
          balances: oneTokenEach,
        ),
      );

      await pressWithCommand(tester, [LogicalKeyboardKey.digit1, LogicalKeyboardKey.keyS]);
      await settings.finishWrites(tester);

      expect(_selected(tester), 'Main');
      expect(find.byType(SendSheet), findsOneWidget);
      expect(_inSheet(find.text('Main')), findsOneWidget);
    });

    testOnMac('⌘2 to an account that cannot send, then ⌘S before the next frame, opens nothing', (tester) async {
      final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
      await pumpShell(
        tester,
        overrides: shellOverrides(
          accounts: const [mainAccount, vaultAccount],
          settings: settings,
          balances: oneTokenEach,
        ),
      );

      await pressWithCommand(tester, [LogicalKeyboardKey.digit2, LogicalKeyboardKey.keyS]);
      await settings.finishWrites(tester);

      expect(_selected(tester), 'Vault');
      expect(find.byType(ShellSheetView), findsNothing);
    });

    testOnMac('⌘2 then ⌘R while the switch is still being saved opens Receive on the second account', (tester) async {
      final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
      await pumpShell(tester, overrides: _withSlowSettings(settings));

      _accountMenuAccounts(tester).singleWhere((item) => item.label == 'Savings').onSelected!();
      await tester.pumpAndSettle();
      _nativeItem(tester, 'Account', 'Receive').onSelected!();
      await tester.pumpAndSettle();
      await settings.finishWrites(tester);

      expect(_sheetTitled('Receive'), findsOneWidget);
      expect(_inSheet(find.text('Savings')), findsOneWidget);
      expect(_inSheet(find.text('qzSavings')), findsOneWidget);
    });

    group('the account\'s own items, pressed while a switch is still being saved', () {
      String? copied;

      void recordClipboard(WidgetTester tester) {
        copied = null;
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      }

      Future<SlowSettingsService> switchToSavings(WidgetTester tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));
        _accountMenuAccounts(tester).singleWhere((item) => item.label == 'Savings').onSelected!();
        await tester.pumpAndSettle();
        expect(settings.pendingWrites, 1);
        return settings;
      }

      testOnMac('⌘2 then ⌘I opens Get Info on the second account', (tester) async {
        final settings = await switchToSavings(tester);

        _nativeItem(tester, 'Account', 'Get Info').onSelected!();
        await tester.pumpAndSettle();
        await settings.finishWrites(tester);

        expect(find.byType(AccountInfoSheet), findsOneWidget);
        expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Savings')), findsOneWidget);
      });

      testOnMac('⌘2 then ⇧⌘C copies the second account\'s address', (tester) async {
        recordClipboard(tester);
        final settings = await switchToSavings(tester);

        _nativeItem(tester, 'Account', 'Copy Address').onSelected!();
        await tester.pumpAndSettle();
        expect(copied, isNull);
        await settings.finishWrites(tester);

        expect(copied, 'qzSavings');
        await tester.pump(AccountNoteNotifier.failureShownFor);
      });

      testOnMac('when the switch fails, the Get Info and Copy Address pressed while it waited are dropped', (
        tester,
      ) async {
        recordClipboard(tester);
        final settings = await switchToSavings(tester);

        _nativeItem(tester, 'Account', 'Get Info').onSelected!();
        _nativeItem(tester, 'Account', 'Copy Address').onSelected!();
        await tester.pumpAndSettle();
        await settings.failWrites(tester, StateError('disk full'));

        expect(find.byType(AccountInfoSheet), findsNothing);
        expect(copied, isNull);
      });

      testOnMac('an item the account switched to does not offer is not done on it', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(
          tester,
          overrides: shellOverrides(
            accounts: const [mainAccount, vaultAccount],
            settings: settings,
            balances: oneTokenEach,
          ),
        );
        _accountMenuAccounts(tester).singleWhere((item) => item.label == 'Vault').onSelected!();
        await tester.pumpAndSettle();

        _nativeItem(tester, 'Account', 'Show Recovery Phrase…').onSelected!();
        await tester.pumpAndSettle();
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Vault');
        expect(find.byType(ShellSheetView), findsNothing);
      });
    });

    testOnMac('View → Next and Previous Sidebar Item (⌥⌘↓, ⌥⌘↑) walk the sidebar, Mining Rewards included, and '
        'go round at its ends', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      expect(
        _nativeItem(tester, 'View', 'Next Sidebar Item').shortcut,
        _isShortcut(LogicalKeyboardKey.arrowDown, meta: true, alt: true),
      );
      expect(
        _nativeItem(tester, 'View', 'Previous Sidebar Item').shortcut,
        _isShortcut(LogicalKeyboardKey.arrowUp, meta: true, alt: true),
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

    testOnMac('View → Refresh (⇧⌘R) reads the wallet again from the network, once', (tester) async {
      final polling = FakeHistoryPollingManager();
      await pumpShell(tester, polling: polling, overrides: _withActive(const RegularAccount(mainAccount)));

      final refresh = _nativeItem(tester, 'View', 'Refresh');
      expect(refresh.shortcut, _isShortcut(LogicalKeyboardKey.keyR, meta: true, shift: true));

      refresh.onSelected!();
      await tester.pumpAndSettle();

      expect(polling.calls, ['manualRefresh']);
    });

    testOnMac('Refresh stays available while a sheet is open: it changes nothing the sheet was opened on', (
      tester,
    ) async {
      final polling = FakeHistoryPollingManager();
      await pumpShell(tester, polling: polling, overrides: _withActive(const RegularAccount(mainAccount)));
      _nativeItem(tester, 'Account', 'Receive').onSelected!();
      await tester.pumpAndSettle();

      _nativeItem(tester, 'View', 'Refresh').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Receive'), findsOneWidget);
      expect(polling.calls, ['manualRefresh']);
    });

    testOnMac('a Refresh that fails leaves the app running', (tester) async {
      final polling = FakeHistoryPollingManager()..refreshError = StateError('the node did not answer');
      await pumpShell(tester, polling: polling, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'View', 'Refresh').onSelected!();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(polling.calls, ['manualRefresh']);
      expect(find.byType(Sidebar), findsOneWidget);
    });

    testOnMac('while a sheet is open, the items that open sheets are disabled', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      _nativeItem(tester, 'Account', 'Receive').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheetTitled('Receive'), findsOneWidget);
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
      expect(_nativeItem(tester, 'Account', 'New Account').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Hide Sidebar').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Next Sidebar Item').onSelected, isNull);
      expect(_nativeItem(tester, 'View', 'Refresh').onSelected, isNull);

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
          ('Get Info', true),
          ('Copy Address', true),
          ('Rename…', true),
          ('Disconnect Hardware Account…', true),
          ('New Account', true),
          ('Import Wallet…', true),
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

    testOnWindowsAndLinux('View → Refresh, with Ctrl+Shift+R, reads the wallet again from the network', (tester) async {
      final polling = FakeHistoryPollingManager();
      await pumpShell(tester, polling: polling, overrides: _withActive(const RegularAccount(mainAccount)));

      await openMenu(tester, 'View');
      final refresh = find.widgetWithText(MenuItemButton, 'Refresh');
      expect(
        tester.widget<MenuItemButton>(refresh).shortcut,
        _isShortcut(LogicalKeyboardKey.keyR, control: true, shift: true),
      );
      await tester.tap(refresh);
      await tester.pumpAndSettle();

      expect(polling.calls, ['manualRefresh']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(polling.calls, ['manualRefresh', 'manualRefresh']);
      // Ctrl+Shift+R is not Ctrl+R: Receive stays shut.
      expect(find.byType(ShellSheetView), findsNothing);
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

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool alt = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    Future<void> next(WidgetTester tester) => press(tester, LogicalKeyboardKey.arrowDown, alt: true);
    Future<void> previous(WidgetTester tester) => press(tester, LogicalKeyboardKey.arrowUp, alt: true);

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

    testOnWindowsAndLinux('Ctrl+Alt+Down and Ctrl+Alt+Up walk the sidebar and go round at its ends', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await previous(tester);
      expect(_selected(tester), 'Mining Rewards');

      await next(tester);
      expect(_selected(tester), 'Main');

      await next(tester);
      expect(_selected(tester), 'Team');
    });

    testOnWindowsAndLinux('Ctrl+Tab no longer walks the sidebar', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));

      await press(tester, LogicalKeyboardKey.tab);

      expect(_selected(tester), 'Main');
    });

    testOnWindowsAndLinux('a shortcut changed in Settings works from the keyboard, and its old keys no longer do', (
      tester,
    ) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
      await container
          .read(shortcutBindingsProvider.notifier)
          .setShortcut(AppCommand.receive, const KeyCombo(LogicalKeyboardKey.keyJ, KeyModifiers(control: true)));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyR);
      expect(find.byType(ShellSheetView), findsNothing);

      await press(tester, LogicalKeyboardKey.keyJ);
      expect(_sheetTitled('Receive'), findsOneWidget);
    });

    testOnWindowsAndLinux('changed account keys reach the accounts', (tester) async {
      await pumpShell(tester, overrides: _withActive(const RegularAccount(mainAccount)));
      final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
      await container.read(shortcutBindingsProvider.notifier).setAccountModifiers(const KeyModifiers(alt: true));
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.digit3);
      expect(_selected(tester), 'Main');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(_selected(tester), 'Vault');
    });

    for (final (key, name, title) in [
      (LogicalKeyboardKey.keyR, 'Ctrl+R', 'Receive'),
      (LogicalKeyboardKey.keyS, 'Ctrl+S', 'Send'),
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
      await next(tester);
      await press(tester, LogicalKeyboardKey.keyS);
      await press(tester, LogicalKeyboardKey.keyN);

      expect(_selected(tester), 'Main');
      expect(_sheetTitled('Receive'), findsOneWidget);
      expect(find.byType(ShellSheetView), findsOneWidget);
    });

    group('while an account switch is still being saved', () {
      testOnWindowsAndLinux('Ctrl+2 then Ctrl+R opens Receive on the second account, its header and address alike', (
        tester,
      ) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));

        await press(tester, LogicalKeyboardKey.digit2);
        await press(tester, LogicalKeyboardKey.keyR);
        await settings.finishWrites(tester);

        expect(_sheetTitled('Receive'), findsOneWidget);
        expect(_inSheet(find.text('Savings')), findsOneWidget);
        expect(_inSheet(find.text('Main')), findsNothing);
        expect(_inSheet(find.text('qzSavings')), findsOneWidget);
        expect(tester.widget<QuantusQr>(_inSheet(find.byType(QuantusQr))).accountId, 'qzSavings');
      });

      testOnWindowsAndLinux('Ctrl+2 then Ctrl+S opens Send on the second account', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));

        await press(tester, LogicalKeyboardKey.digit2);
        await press(tester, LogicalKeyboardKey.keyS);
        await settings.finishWrites(tester);

        expect(find.byType(SendSheet), findsOneWidget);
        expect(_inSheet(find.text('Savings')), findsOneWidget);
        expect(_inSheet(find.text('Main')), findsNothing);
      });

      testOnWindowsAndLinux('two presses of Ctrl+Alt+Down move two rows', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));

        await next(tester);
        await next(tester);
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Mining Rewards');
      });

      testOnWindowsAndLinux('Ctrl+2 then a click on Mining Rewards ends on Mining Rewards', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));

        await press(tester, LogicalKeyboardKey.digit2);
        await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Mining Rewards')));
        await tester.pumpAndSettle();
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Mining Rewards');
        expect(find.byType(MiningRewardsPane), findsOneWidget);
      });

      for (final (key, name, sheet) in [
        (LogicalKeyboardKey.keyS, 'Ctrl+S', 'Send'),
        (LogicalKeyboardKey.keyR, 'Ctrl+R', 'Receive'),
      ]) {
        testOnWindowsAndLinux('when the switch fails, $name pressed while it waited opens nothing, and says why', (
          tester,
        ) async {
          final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
          await pumpShell(tester, overrides: _withSlowSettings(settings));

          await press(tester, LogicalKeyboardKey.digit2);
          await press(tester, key);
          await settings.failWrites(tester, StateError('disk full'));

          expect(find.byType(ShellSheetView), findsNothing, reason: '$sheet must not open on Main');
          expect(_selected(tester), 'Main');
          expect(find.text('Could not switch account'), findsOneWidget);
          expect(find.text('Savings could not be made the active account: Bad state: disk full'), findsOneWidget);

          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(find.text('Could not switch account'), findsNothing);
        });
      }

      List<Override> withVault(SlowSettingsService settings) =>
          shellOverrides(accounts: const [mainAccount, vaultAccount], settings: settings, balances: oneTokenEach);

      testOnWindowsAndLinux(
        'from an account that cannot send, Ctrl+1 then Ctrl+S opens Send on the account switched to',
        (tester) async {
          final settings = SlowSettingsService(activeAccount: const RegularAccount(vaultAccount));
          await pumpShell(tester, overrides: withVault(settings));

          await press(tester, LogicalKeyboardKey.digit1);
          await press(tester, LogicalKeyboardKey.keyS);
          await settings.finishWrites(tester);

          expect(find.byType(SendSheet), findsOneWidget);
          expect(_inSheet(find.text('Main')), findsOneWidget);
        },
      );

      /// Presses [keys] one after another with Ctrl held, before any frame
      /// is drawn: the menus still show what they did before the first key.
      Future<void> pressWithinOneFrame(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        for (final key in keys) {
          await tester.sendKeyEvent(key);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      testOnWindowsAndLinux('from an account that cannot send, Ctrl+1 then Ctrl+S before the next frame opens Send '
          'on the account switched to', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(vaultAccount));
        await pumpShell(tester, overrides: withVault(settings));

        await pressWithinOneFrame(tester, [LogicalKeyboardKey.digit1, LogicalKeyboardKey.keyS]);
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Main');
        expect(find.byType(SendSheet), findsOneWidget);
        expect(_inSheet(find.text('Main')), findsOneWidget);
      });

      testOnWindowsAndLinux('Ctrl+2 to an account that cannot send, then Ctrl+S before the next frame, opens '
          'nothing', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: withVault(settings));

        await pressWithinOneFrame(tester, [LogicalKeyboardKey.digit2, LogicalKeyboardKey.keyS]);
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Vault');
        expect(find.byType(ShellSheetView), findsNothing);
      });

      testOnWindowsAndLinux('Ctrl+2 to an account that cannot send, then Ctrl+S, opens nothing', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: withVault(settings));

        await press(tester, LogicalKeyboardKey.digit2);
        await press(tester, LogicalKeyboardKey.keyS);
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Vault');
        expect(find.byType(ShellSheetView), findsNothing);
      });

      testOnWindowsAndLinux('the toolbar keeps showing what the active account offers while a switch waits', (
        tester,
      ) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(vaultAccount));
        await pumpShell(tester, overrides: withVault(settings));

        await press(tester, LogicalKeyboardKey.digit1);

        expect(tester.widget<ToolbarAction>(_toolbarButton('Send')).onPressed, isNull);
        await settings.finishWrites(tester);
        expect(tester.widget<ToolbarAction>(_toolbarButton('Send')).onPressed, isNotNull);
      });

      testOnWindowsAndLinux('after a failed switch, the shortcuts pressed later work again', (tester) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));
        await press(tester, LogicalKeyboardKey.digit2);
        await settings.failWrites(tester, StateError('disk full'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        await press(tester, LogicalKeyboardKey.keyR);

        expect(_sheetTitled('Receive'), findsOneWidget);
        expect(_inSheet(find.text('qzMain')), findsOneWidget);
      });

      testOnWindowsAndLinux('a switch pressed after a sheet\'s shortcut does nothing once that sheet is open', (
        tester,
      ) async {
        final settings = SlowSettingsService(activeAccount: const RegularAccount(mainAccount));
        await pumpShell(tester, overrides: _withSlowSettings(settings));

        await press(tester, LogicalKeyboardKey.digit2);
        await press(tester, LogicalKeyboardKey.keyR);
        await press(tester, LogicalKeyboardKey.digit1);
        await settings.finishWrites(tester);

        expect(_selected(tester), 'Savings');
        expect(_inSheet(find.text('Savings')), findsOneWidget);
        expect(_inSheet(find.text('qzSavings')), findsOneWidget);
      });
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
