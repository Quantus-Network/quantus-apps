import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/recovery_phrase_input.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

const _phrase = 'zebra abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

/// The address the fake derives for [_phrase].
const _rootId = 'qz(zebra)';

const _storedPhrase = 'stored abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

/// Main and Savings in Wallet 1, Vault in the Cold Wallet, Trading in Wallet 2:
/// the next free wallet index is 3. With [leavesAGap], only Main and Trading,
/// so index 1 is free.
Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  Future<List<Account>> Function()? scan,
  bool reduceMotion = true,
  bool leavesAGap = false,
}) async {
  final device = FakeWalletDevice()..store(leavesAGap ? [mainAccount] : [mainAccount, savingsAccount]);
  device.storage.mnemonics[0] = _storedPhrase;
  if (!leavesAGap) device.storage.accounts.add(vaultAccount);
  device.storage.accounts.add(tradingAccount);
  device.storage.mnemonics[2] = 'trading words';
  if (scan != null) device.scan = scan;
  await pumpShell(
    tester,
    reduceMotion: reduceMotion,
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

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _addRow => _inSidebar(find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder get _sheet => find.byType(ShellSheetView);

Finder get _field => _inSheet(find.byType(EditableText));

Finder get _importButton => _inSheet(find.widgetWithText(QuantusButton, 'Import Wallet'));

Finder get _finding => find.text("Finding this wallet's accounts");

Finder get _headingField => _inSidebar(find.byType(EditableText));

bool _canImport(WidgetTester tester) => !tester.widget<QuantusButton>(_importButton).isDisabled;

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('Import Wallet…')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String phrase) async {
  await tester.enterText(_field, phrase);
  await tester.pump();
}

/// Opens the sheet, types [phrase] and presses Import, without waiting for it.
Future<void> _startImport(WidgetTester tester, {String phrase = _phrase}) async {
  await _openSheet(tester);
  await _enter(tester, phrase);
  await tester.tap(_importButton);
  await tester.pump();
}

/// Lets a scan's failure reach its dialog.
Future<void> _pumpToDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String? _activeId(WidgetTester tester) => _container(tester).read(activeAccountProvider).value?.account.accountId;

List<PlatformMenuItem> _accountMenuItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
}

PlatformMenuItem _menuBarItem(WidgetTester tester) =>
    _accountMenuItems(tester).singleWhere((item) => item.label == 'Import Wallet…');

void main() {
  group('where it is offered', () {
    testOnMac('the Add Account menu has Import Wallet… after a separator', (tester) async {
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
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
      expect(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)).first).dy,
        lessThan(tester.getTopLeft(find.descendant(of: _menu, matching: find.text('Import Wallet…'))).dy),
      );
    });

    testOnMac('the Account menu has it in a group of its own after New Account, with no shortcut', (tester) async {
      await _pump(tester);

      final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
      final groups = menus.singleWhere((menu) => menu.label == 'Account').menus.cast<PlatformMenuItemGroup>();
      final at = groups.indexWhere((group) => group.members.any((item) => item.label == 'New Account'));

      expect(groups[at].members, hasLength(1));
      expect(groups[at + 1].members.map((item) => item.label), ['Import Wallet…', 'Connect Cold Wallet…']);
      expect(_menuBarItem(tester).shortcut, isNull);
    });

    testOnMac('the menu bar item opens the sheet, and is disabled while a sheet is open', (tester) async {
      await _pump(tester);

      _menuBarItem(tester).onSelected!();
      await tester.pumpAndSettle();

      expect(_importButton, findsOneWidget);
      expect(_menuBarItem(tester).onSelected, isNull);
    });
  });

  group('the sheet', () {
    testOnMac('has a masked field, a word count and Paste, with Import disabled until something is typed', (
      tester,
    ) async {
      await _pump(tester);
      await _openSheet(tester);

      expect(find.byType(RecoveryPhraseInput), findsOneWidget);
      expect(find.text('0 WORDS'), findsOneWidget);
      expect(_inSheet(find.widgetWithText(ToolbarAction, 'Paste')), findsOneWidget);
      expect(_canImport(tester), isFalse);

      await _enter(tester, _phrase);

      final controller = tester.widget<EditableText>(_field).controller as ObscuringTextEditingController;
      expect(controller.obscured, isTrue);
      expect(find.text('12 WORDS'), findsOneWidget);
      expect(_canImport(tester), isTrue);
    });

    testOnMac('the phrase field has the focus as soon as the sheet opens', (tester) async {
      await _pump(tester);

      await _openSheet(tester);

      expect(tester.widget<EditableText>(_field).focusNode.hasFocus, isTrue);
    });

    testOnMac('what is typed right after it opens goes into the field', (tester) async {
      await _pump(tester);
      await _openSheet(tester);

      tester.testTextInput.enterText(_phrase);
      await tester.pump();

      expect(tester.widget<EditableText>(_field).controller.text, _phrase);
      expect(find.text('12 WORDS'), findsOneWidget);
    });

    testOnMac('Esc from the focused field closes it and nothing is stored', (tester) async {
      final device = await _pump(tester);
      await _openSheet(tester);
      expect(tester.widget<EditableText>(_field).focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(device.storage.mnemonics.containsKey(3), isFalse);
    });

    testOnMac('Cancel closes it and nothing is stored', (tester) async {
      final device = await _pump(tester);
      await _openSheet(tester);
      await _enter(tester, _phrase);

      await tester.tap(_inSheet(find.widgetWithText(QuantusButton, 'Cancel')));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(device.storage.mnemonics.containsKey(3), isFalse);
    });

    testOnMac('a wrong word count says so under the field, and the sheet stays', (tester) async {
      final device = await _pump(tester);

      await _startImport(tester, phrase: 'zebra abandon about');
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Recovery phrase must be 12 or 24 words')), findsOneWidget);
      expect(_importButton, findsOneWidget);
      expect(device.storage.mnemonics.containsKey(3), isFalse);
    });

    testOnMac('a phrase already in the app says so, and nothing changes', (tester) async {
      final device = await _pump(tester);
      final before = List.of(device.storage.accounts);

      await _startImport(tester, phrase: _storedPhrase);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('This wallet is already in the app')), findsOneWidget);
      expect(device.storage.accounts, before);
      expect(device.storage.mnemonics.containsKey(3), isFalse);
      expect(_activeId(tester), mainAccount.accountId);
    });

    testOnMac('takes the next free wallet slot', (tester) async {
      final device = await _pump(tester, leavesAGap: true);

      await _startImport(tester);
      await tester.pumpAndSettle();

      expect(device.storage.mnemonics[1], _phrase);
      expect(device.storage.accounts.singleWhere((a) => a.accountId == _rootId).walletIndex, 1);
    });

    testOnMac('shows a moving line while importing', (tester) async {
      final scanned = Completer<List<Account>>();
      await _pump(tester, scan: () => scanned.future, reduceMotion: false);

      await _startImport(tester);
      await tester.pump();

      expect(_inSheet(_finding), findsOneWidget);
      expect(_canImport(tester), isFalse);
      String face() =>
          tester.widget<Text>(find.descendant(of: find.byType(TerminalSpinner), matching: find.byType(Text))).data!;
      final first = face();
      await tester.pump(TerminalLine.busyTurn);
      expect(face(), isNot(first));

      scanned.complete([]);
      await tester.pumpAndSettle();
    });

    testOnMac('where less motion is asked for, the line stands still', (tester) async {
      final scanned = Completer<List<Account>>();
      await _pump(tester, scan: () => scanned.future);

      await _startImport(tester);
      await tester.pump();

      expect(_inSheet(_finding), findsOneWidget);
      expect(find.byType(TerminalSpinner), findsNothing);

      scanned.complete([]);
      await tester.pumpAndSettle();
    });

    testOnMac('Esc, the close button and a click outside do not close it while importing', (tester) async {
      final scanned = Completer<List<Account>>();
      await _pump(tester, scan: () => scanned.future);
      await _startImport(tester);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_importButton, findsOneWidget);

      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pumpAndSettle();
      expect(_importButton, findsOneWidget);

      await tester.tapAt(const Offset(4, 400));
      await tester.pumpAndSettle();
      expect(_importButton, findsOneWidget);

      scanned.complete([]);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testOnMac('a failed scan offers Try again, which scans again', (tester) async {
      var attempts = 0;
      final device = await _pump(tester, scan: () async => ++attempts == 1 ? throw StateError('offline') : []);

      await _startImport(tester);
      await _pumpToDialog(tester);

      expect(find.text('Account scan failed'), findsOneWidget);
      await tester.tap(find.widgetWithText(QuantusButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(device.scans, 2);
      expect(device.storage.pendingScans, isEmpty);
      expect(_sheet, findsNothing);
    });

    testOnMac('Skip keeps the wallet with its first account, the scan left for the next start', (tester) async {
      final device = await _pump(tester, scan: () async => throw StateError('offline'));

      await _startImport(tester);
      await _pumpToDialog(tester);
      await tester.tap(find.widgetWithText(QuantusButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(device.scans, 1);
      expect(device.storage.pendingScans, {3: _rootId});
      expect(_sheet, findsNothing);
      expect(_activeId(tester), _rootId);
    });

    testOnMac('a failed import says so, keeps the phrase, and can be tried again', (tester) async {
      final device = await _pump(tester);
      device.storage.addAccountError = StateError('disk full');

      await _startImport(tester);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text("Couldn't import the wallet")), findsOneWidget);
      expect(tester.widget<EditableText>(_field).controller.text, _phrase);
      expect(device.storage.mnemonics.containsKey(3), isFalse);
      expect(_canImport(tester), isTrue);

      device.storage.addAccountError = null;
      await tester.tap(_importButton);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(device.storage.mnemonics[3], _phrase);
    });
  });

  group('once imported', () {
    testOnMac('the sheet closes, the first account is active, its wallet open, its heading ready to rename', (
      tester,
    ) async {
      final device = await _pump(tester);

      await _startImport(tester);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(_activeId(tester), _rootId);
      final root = device.storage.accounts.singleWhere((a) => a.accountId == _rootId);
      expect(_inSidebar(find.widgetWithText(SidebarRow, root.name)), findsOneWidget);
      final field = tester.widget<EditableText>(_headingField);
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.text, 'Wallet 3');
      expect(field.controller.selection.textInside(field.controller.text), 'Wallet 3');
    });

    testOnMac('the heading keeps the focus when the sheet slides away', (tester) async {
      await _pump(tester, reduceMotion: false);

      await _startImport(tester);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(tester.widget<EditableText>(_headingField).focusNode.hasFocus, isTrue);
    });

    testOnMac('an account the scan chose, as the first has no history, stays active', (tester) async {
      const found = Account(walletIndex: 3, index: 2, name: 'Found', accountId: 'qzFound3');
      final device = await _pump(tester, scan: () async => const [found]);

      await _startImport(tester);
      await tester.pumpAndSettle();

      expect(_activeId(tester), found.accountId);
      expect(device.storage.activeAccount?.account.accountId, found.accountId);
      // Under the name it was stored with, not the one the scan found it by.
      final stored = device.storage.accounts.singleWhere((a) => a.accountId == found.accountId);
      expect(stored.name, isNot(found.name));
      expect(_container(tester).read(activeAccountProvider).value?.account.name, stored.name);
      expect(_headingField, findsOneWidget);
    });

    testOnMac('Esc on the heading leaves it "Wallet N"', (tester) async {
      await _pump(tester);
      await _startImport(tester);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_headingField, findsNothing);
      expect(_inSidebar(find.text('WALLET 3')), findsOneWidget);
      expect(_container(tester).read(walletNameProvider(3)), isNull);
    });

    testOnMac('with the sidebar hidden nothing opens to rename, and the top bar says it was imported', (tester) async {
      await _pump(tester);
      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      _menuBarItem(tester).onSelected!();
      await tester.pumpAndSettle();
      await _enter(tester, _phrase);
      await tester.tap(_importButton);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(find.byType(Sidebar), findsNothing);
      expect(_container(tester).read(sidebarRenameProvider), isNull);
      expect(_container(tester).read(shellSheetProvider), isNull);
      expect(find.descendant(of: find.byType(ShellTopBar), matching: find.text('Wallet imported')), findsOneWidget);
    });

    testOnMac("the wallet's Encrypted account appears after the sheet has closed", (tester) async {
      final restored = Completer<void>();
      final device = await _pump(tester);
      device.storage.encryptedAccountsGate = restored.future;

      await _startImport(tester);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      bool isListed() => (_container(tester).read(accountsProvider).value ?? const <Account>[]).any(
        (a) => a.walletIndex == 3 && a.accountType == AccountType.encrypted,
      );
      expect(isListed(), isFalse);

      restored.complete();
      await tester.pumpAndSettle();

      expect(isListed(), isTrue);
    });
  });
}
