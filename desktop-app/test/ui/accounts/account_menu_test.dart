import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/settings/keyboard_shortcuts_step.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

const _cold = Account(walletIndex: 1, index: 0, name: 'Cold', accountId: 'qzCold', accountType: AccountType.keystone);
const _trading = Account(walletIndex: 2, index: 0, name: 'Trading', accountId: 'qzTrading');
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

String? _clipboard;
Object? _clipboardError;

/// Main (active) and Savings in the first wallet with its encrypted account,
/// a Keystone account, Trading alone in a second wallet, and Team.
Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  List<Account>? accounts,
  DisplayAccount? active,
  RemoteConfigModel? remoteConfig,
}) async {
  _clipboard = null;
  _clipboardError = null;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method != 'Clipboard.setData') return null;
    if (_clipboardError case final error?) throw error;
    _clipboard = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

  final device = FakeWalletDevice()..store(accounts ?? [mainAccount, savingsAccount]);
  if (accounts == null) {
    device.storage.accounts.addAll([_cold, _trading]);
    device.storage.mnemonics[2] = 'trading words';
    device.storage.multisigStore.add(_team);
    device.storage.strings[KeptOpenWalletsNotifier.settingsKey] = '0,1,2';
    device.storage.bools[KeptOpenMultisigsNotifier.settingsKey] = true;
  }
  if (active != null) device.storage.activeAccount = active;
  if (remoteConfig != null) device.remoteConfig = remoteConfig;
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

String? _activeId(WidgetTester tester) => _container(tester).read(activeAccountProvider).value?.account.accountId;

Finder _sidebarRow(String name) => find.descendant(
  of: find.byType(Sidebar),
  matching: find.ancestor(of: find.text(name), matching: find.byType(SidebarRow)),
);

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

/// The name field open in the sidebar, on a row or a wallet heading.
Finder get _sidebarField => find.descendant(of: find.byType(Sidebar), matching: find.byType(EditableText));

Future<void> _renameFromMenu(WidgetTester tester, Finder target) async {
  await _rightClick(tester, target);
  await _choose(tester, 'Rename…');
}

Future<void> _typeAndReturn(WidgetTester tester, String name) async {
  await tester.enterText(_sidebarField, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

String _storedName(FakeWalletDevice device, String accountId) =>
    device.storage.accounts.firstWhere((a) => a.accountId == accountId).name;

Finder _inSidebar(String text) => find.descendant(of: find.byType(Sidebar), matching: find.text(text));

List<String> _menuLabels(WidgetTester tester) => [
  for (final element in find.descendant(of: _menu, matching: find.byType(Text)).evaluate())
    if ((element.widget as Text).data case final label? when label.length > 1) label,
];

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: _menu, matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// The native menus' items under Account, groups opened up.
List<PlatformMenuItem> _accountMenuItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  final account = menus.singleWhere((menu) => menu.label == 'Account');
  return [
    for (final entry in account.menus)
      if (entry is PlatformMenuItemGroup) ...entry.members.cast<PlatformMenuItem>() else entry,
  ];
}

void main() {
  group('the context menu', () {
    testOnMac('a right-click on an account opens its menu, the Mac\'s words, and leaves the active account', (
      tester,
    ) async {
      await _pump(tester);
      await _rightClick(tester, _sidebarRow('Savings'));

      expect(_menuLabels(tester), [
        'Get Info',
        'Copy Address',
        'Rename…',
        'Show Recovery Phrase…',
        'Disconnect Account…',
      ]);
      expect(_activeId(tester), 'qzMain');
    });

    testOnMac('a row\'s menu shows no shortcuts, which the menu bar keeps', (tester) async {
      await _pump(tester);
      await _rightClick(tester, _sidebarRow('Savings'));

      expect(find.descendant(of: _menu, matching: find.byIcon(CupertinoIcons.command)), findsNothing);
      expect(find.descendant(of: _menu, matching: find.byIcon(CupertinoIcons.shift)), findsNothing);
      final items = _accountMenuItems(tester);
      expect(items.singleWhere((item) => item.label == 'Get Info').shortcut, isNotNull);
      expect(items.singleWhere((item) => item.label == 'Copy Address').shortcut, isNotNull);
    });

    testOnMac('a Control-click opens the menu and does not switch account', (tester) async {
      await _pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final gesture = await tester.startGesture(
        tester.getCenter(_sidebarRow('Savings')),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(_menu, findsOneWidget);
      expect(_activeId(tester), 'qzMain');
    });

    testOnMac('each kind of account offers what the rules allow', (tester) async {
      await _pump(tester);

      await _rightClick(tester, _sidebarRow('Encrypted Account').first);
      expect(_menuLabels(tester), ['Get Info', 'Copy Inner Hash']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _rightClick(tester, _sidebarRow('Cold'));
      expect(_menuLabels(tester), ['Get Info', 'Copy Address', 'Rename…', 'Disconnect Hardware Account…']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _rightClick(tester, _sidebarRow('Team'));
      expect(_menuLabels(tester), ['Get Info', 'Copy Address', 'Rename…', 'Show Signers…', 'Disconnect Multisig…']);
    });

    testOnMac('the last account of the first wallet offers no Disconnect', (tester) async {
      await _pump(tester, accounts: [mainAccount]);
      await _rightClick(tester, _sidebarRow('Main'));

      expect(_menuLabels(tester), ['Get Info', 'Copy Address', 'Rename…', 'Show Recovery Phrase…']);
    });

    testOnMac('a software wallet\'s heading offers Rename, its recovery phrase, opened in Settings, and the moves', (
      tester,
    ) async {
      await _pump(tester);
      await _rightClick(tester, find.descendant(of: find.byType(Sidebar), matching: find.text('WALLET 2')));

      expect(_menuLabels(tester), ['Rename…', 'Show Recovery Phrase…', 'Move Up', 'Move Down']);
      await _choose(tester, 'Show Recovery Phrase…');
      expect(find.byType(SettingsSheet), findsOneWidget);
      expect(find.byKey(SettingsSheet.continueKey), findsOneWidget);
    });

    testOnMac('a right-click anywhere along a wallet heading opens its menu, not only on its name', (tester) async {
      await _pump(tester);
      final sidebar = tester.getRect(find.byType(Sidebar));
      final gesture = await tester.startGesture(
        Offset(
          sidebar.right - 40,
          tester.getCenter(find.descendant(of: find.byType(Sidebar), matching: find.text('WALLET 2'))).dy,
        ),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_menuLabels(tester), ['Rename…', 'Show Recovery Phrase…', 'Move Up', 'Move Down']);
    });

    testOnMac('a cold wallet\'s heading offers only Connect Cold Wallet…, which opens it, and the moves', (
      tester,
    ) async {
      await _pump(tester);
      await _rightClick(tester, _inSidebar('COLD WALLET'));

      expect(_menuLabels(tester), ['Connect Cold Wallet…', 'Move Up', 'Move Down']);
      await _choose(tester, 'Connect Cold Wallet…');
      expect(_container(tester).read(shellSheetProvider), ShellSheet.connectColdWallet);
    });

    testOnMac('with cold wallets turned off remotely, a cold wallet\'s heading offers only the moves', (tester) async {
      await _pump(tester, remoteConfig: RemoteConfigModel.fromJson({'enableKeystoneHardwareWallet': false}));
      await _rightClick(tester, _inSidebar('COLD WALLET'));

      expect(_menuLabels(tester), ['Move Up', 'Move Down']);
    });

    for (final (label, sheet) in [
      ('Create Multisig…', ShellSheet.createMultisig),
      ('Manage Multisigs…', ShellSheet.manageMultisigs),
    ]) {
      testOnMac('the multisigs\' heading offers Create Multisig… and Manage Multisigs…; $label opens its sheet', (
        tester,
      ) async {
        await _pump(tester);
        await _rightClick(tester, _inSidebar('MULTISIGS'));

        expect(_menuLabels(tester), ['Create Multisig…', 'Manage Multisigs…', 'Move Up', 'Move Down']);
        await _choose(tester, label);
        expect(_container(tester).read(shellSheetProvider), sheet);
      });
    }

    testOnMac('on an account that cannot create a multisig, the heading\'s Create Multisig… is unavailable', (
      tester,
    ) async {
      await _pump(tester, active: MultisigDisplayAccount(_team));
      await _rightClick(tester, _inSidebar('MULTISIGS'));

      final row = find.descendant(of: _menu, matching: find.widgetWithText(MenuPanelRow, 'Create Multisig…'));
      expect(tester.widget<MenuPanelRow>(row).isDisabled, isTrue);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_container(tester).read(shellSheetProvider), isNull);
    });

    testOnMac('with multisigs turned off remotely, the multisigs\' heading offers only the moves', (tester) async {
      await _pump(tester, remoteConfig: RemoteConfigModel.fromJson({'enableMultisig': false}));
      await _rightClick(tester, _inSidebar('MULTISIGS'));

      expect(_menuLabels(tester), ['Move Up', 'Move Down']);
    });

    testOnMac('the items act on the account right-clicked, not the active one', (tester) async {
      await _pump(tester);

      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Get Info');
      expect(find.byType(AccountInfoSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Savings')), findsOneWidget);
      expect(_activeId(tester), 'qzMain');
      Navigator.of(tester.element(find.byType(AccountInfoSheet))).pop();
      await tester.pumpAndSettle();

      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Rename…');
      expect(tester.widget<EditableText>(_sidebarField).controller.text, 'Savings');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Show Recovery Phrase…');
      expect(find.byKey(SettingsSheet.continueKey), findsOneWidget);
      Navigator.of(tester.element(find.byType(AccountInfoSheet))).pop();
      await tester.pumpAndSettle();

      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Disconnect Account…');
      expect(find.byKey(AccountInfoSheet.disconnectButtonKey), findsOneWidget);
    });
  });

  group('renaming in the sidebar', () {
    testOnMac('Rename… turns the row\'s name into a field, focused, with the name selected', (tester) async {
      await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));

      expect(find.byType(AccountInfoSheet), findsNothing);
      final field = tester.widget<EditableText>(_sidebarField);
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.text, 'Savings');
      expect(field.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 7));
    });

    testOnMac('the field takes the name\'s place without moving the rows below', (tester) async {
      await _pump(tester);
      final before = tester.getRect(_sidebarRow('Trading'));

      await _renameFromMenu(tester, _sidebarRow('Savings'));

      expect(_sidebarField, findsOneWidget);
      expect(tester.getRect(_sidebarRow('Trading')), before);
    });

    testOnMac('Return keeps the name typed, and the row shows it', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));

      await _typeAndReturn(tester, '  Rainy day ');

      expect(_sidebarField, findsNothing);
      expect(_sidebarRow('Rainy day'), findsOneWidget);
      expect(_storedName(device, 'qzSavings'), 'Rainy day');
    });

    testOnMac('clicking elsewhere keeps it, as Return does', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      await tester.enterText(_sidebarField, 'Rainy day');

      await tester.tap(find.byType(AccountPane), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(_sidebarField, findsNothing);
      expect(_storedName(device, 'qzSavings'), 'Rainy day');
    });

    testOnMac('starting another rename from the menu bar keeps what was typed in the first', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      await tester.enterText(_sidebarField, 'Rainy day');

      _accountMenuItems(tester).singleWhere((item) => item.label == 'Rename…').onSelected!();
      await tester.pumpAndSettle();

      expect(_storedName(device, 'qzSavings'), 'Rainy day');
      expect(tester.widget<EditableText>(_sidebarField).controller.text, 'Main');
    });

    testOnMac('hiding the sidebar keeps what was typed', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      await tester.enterText(_sidebarField, 'Rainy day');

      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(_storedName(device, 'qzSavings'), 'Rainy day');
    });

    testOnMac('a wallet name typed is kept when another rename starts', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _inSidebar('WALLET 2'));
      await tester.enterText(_sidebarField, 'Trading desk');

      _accountMenuItems(tester).singleWhere((item) => item.label == 'Rename…').onSelected!();
      await tester.pumpAndSettle();

      expect(device.storage.names[2], 'Trading desk');
    });

    testOnMac('Escape, then hiding the sidebar, still writes nothing', (tester) async {
      final device = await _pump(tester);
      device.storage.writeError = StateError('nothing should be written');
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      await tester.enterText(_sidebarField, 'Rainy day');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(_storedName(device, 'qzSavings'), 'Savings');
    });

    testOnMac('Escape puts the name back and writes nothing', (tester) async {
      final device = await _pump(tester);
      device.storage.writeError = StateError('nothing should be written');
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      await tester.enterText(_sidebarField, 'Rainy day');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_sidebarField, findsNothing);
      expect(_sidebarRow('Savings'), findsOneWidget);
      expect(_storedName(device, 'qzSavings'), 'Savings');
    });

    testOnMac('a blank name is not kept, and the row says why in ember', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));

      await _typeAndReturn(tester, '   ');

      expect(_sidebarRow('Savings'), findsOneWidget);
      expect(_storedName(device, 'qzSavings'), 'Savings');
      final note = tester.widget<Text>(
        find.descendant(of: _sidebarRow('Savings'), matching: find.text("Account name can't be empty")),
      );
      expect(note.style?.color, tester.element(find.byType(Sidebar)).colorsV3.semanticEmber);
      await tester.pump(AccountNoteNotifier.failureShownFor);
    });

    testOnMac('a name that fails to save is not kept, and the row says so', (tester) async {
      final device = await _pump(tester);
      device.storage.writeError = StateError('disk full');
      await _renameFromMenu(tester, _sidebarRow('Savings'));

      await _typeAndReturn(tester, 'Rainy day');

      expect(_sidebarRow('Savings'), findsOneWidget);
      expect(_storedName(device, 'qzSavings'), 'Savings');
      expect(
        find.descendant(of: _sidebarRow('Savings'), matching: find.text('Failed to rename account.')),
        findsOneWidget,
      );
      await tester.pump(AccountNoteNotifier.failureShownFor);
    });

    testOnMac('a wallet heading is renamed in place, and shows the name in capitals', (tester) async {
      final device = await _pump(tester);
      await _renameFromMenu(tester, _inSidebar('WALLET 2'));
      final field = tester.widget<EditableText>(_sidebarField);
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.text, 'Wallet 2');
      expect(field.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 8));

      await _typeAndReturn(tester, 'Trading desk');

      expect(_sidebarField, findsNothing);
      expect(_inSidebar('TRADING DESK'), findsOneWidget);
      expect(device.storage.names[2], 'Trading desk');
    });

    testOnMac('a wallet name that fails to save stays as it was, and the heading says why', (tester) async {
      final device = await _pump(tester);
      device.storage.writeError = StateError('disk full');
      await _renameFromMenu(tester, _inSidebar('WALLET 2'));

      await _typeAndReturn(tester, 'Trading desk');

      expect(_inSidebar('WALLET 2'), findsOneWidget);
      expect(device.storage.names.containsKey(2), isFalse);
      expect(_inSidebar("Couldn't rename the wallet"), findsOneWidget);
      await tester.pump(AccountNoteNotifier.failureShownFor);
      expect(_inSidebar("Couldn't rename the wallet"), findsNothing);
    });

    testOnMac('retrying a wallet rename while its failure still shows keeps the field, and what is typed, when the '
        'message goes', (tester) async {
      final device = await _pump(tester);
      device.storage.writeError = StateError('disk full');
      await _renameFromMenu(tester, _inSidebar('WALLET 2'));
      await _typeAndReturn(tester, 'Trading desk');
      expect(_inSidebar("Couldn't rename the wallet"), findsOneWidget);

      await _renameFromMenu(tester, _inSidebar('WALLET 2'));
      await tester.enterText(_sidebarField, 'Recovered name');
      await tester.pump(AccountNoteNotifier.failureShownFor);
      await tester.pumpAndSettle();

      expect(_inSidebar("Couldn't rename the wallet"), findsNothing);
      final field = tester.widget<EditableText>(_sidebarField);
      expect(field.controller.text, 'Recovered name');
      expect(field.focusNode.hasFocus, isTrue);
      expect(device.storage.names.containsKey(2), isFalse);
    });

    testOnMac('a click on the row while its name is being typed does not switch account', (tester) async {
      await _pump(tester);
      await _renameFromMenu(tester, _sidebarRow('Savings'));
      expect(_sidebarField, findsOneWidget);

      await tester.tap(
        find.descendant(of: _sidebarRow('Savings'), matching: find.byType(DesktopAccountBadge)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(_activeId(tester), 'qzMain');
    });

    testOnMac('the menu bar\'s Rename renames inline, or in Get Info when the sidebar is hidden', (tester) async {
      await _pump(tester);

      _accountMenuItems(tester).singleWhere((item) => item.label == 'Rename…').onSelected!();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(_sidebarField).controller.text, 'Main');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();
      _accountMenuItems(tester).singleWhere((item) => item.label == 'Rename…').onSelected!();
      await tester.pumpAndSettle();
      final field = find.descendant(of: find.byKey(AccountInfoSheet.nameFieldKey), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    });
  });

  group('the menu bar and the shortcuts', () {
    testOnMac('the Account menu offers the active account\'s items, with their keys', (tester) async {
      await _pump(tester);
      final labels = _accountMenuItems(tester).map((item) => item.label).toList();

      expect(
        labels,
        containsAllInOrder(['Get Info', 'Copy Address', 'Rename…', 'Show Recovery Phrase…', 'Disconnect Account…']),
      );
      final getInfo = _accountMenuItems(tester).singleWhere((item) => item.label == 'Get Info');
      final keys = getInfo.shortcut! as SingleActivator;
      expect(
        (keys.trigger, keys.meta, keys.shift, keys.control, keys.alt),
        (LogicalKeyboardKey.keyI, true, false, false, false),
      );
    });

    testOnMac('Command-I opens Get Info on the active account; Shift-Command-C copies its address', (tester) async {
      await _pump(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Main')), findsOneWidget);
      Navigator.of(tester.element(find.byType(AccountInfoSheet))).pop();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(_clipboard, 'qzMain');
      await tester.pump(AccountNoteNotifier.failureShownFor);
    });

    testOnMac('both are listed in Settings › Keyboard Shortcuts', (tester) async {
      await _pump(tester);
      _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsSheet.keyboardShortcutsRowKey));
      await tester.pumpAndSettle();

      expect(find.byKey(KeyboardShortcutsStep.shortcutKey(AppCommand.getInfo)), findsOneWidget);
      expect(find.byKey(KeyboardShortcutsStep.shortcutKey(AppCommand.copyAddress)), findsOneWidget);
    });
  });

  group('the copy note', () {
    testOnMac('copying from the menu notes it on the account\'s row, then the balance comes back', (tester) async {
      await _pump(tester);
      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Copy Address');

      expect(_clipboard, 'qzSavings');
      final note = find.descendant(of: _sidebarRow('Savings'), matching: find.text('Address copied'));
      expect(note, findsOneWidget);
      // The row is one node to a screen reader; the note makes it a live region.
      final node = tester.getSemantics(note);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, contains('Address copied'));

      await tester.pump(AccountNoteNotifier.shownFor);
      await tester.pumpAndSettle();
      expect(note, findsNothing);
    });

    testOnMac('a copy that fails is noted in ember, and the clipboard is left', (tester) async {
      await _pump(tester);
      _clipboardError = PlatformException(code: 'busy', message: 'busy');
      await _rightClick(tester, _sidebarRow('Savings'));
      await _choose(tester, 'Copy Address');

      expect(_clipboard, isNull);
      final note = tester.widget<Text>(
        find.descendant(of: _sidebarRow('Savings'), matching: find.text('Couldn’t copy: busy')),
      );
      expect(note.style?.color, tester.element(find.byType(Sidebar)).colorsV3.semanticEmber);
      await tester.pump(AccountNoteNotifier.failureShownFor);
    });

    testOnMac('with the sidebar hidden, the note shows by the account in the top bar', (tester) async {
      await _pump(tester);
      _container(tester).read(sidebarVisibleProvider.notifier).toggle();
      await tester.pumpAndSettle();

      await _container(tester).read(accountManagerProvider).copy(mainAccount, CopiedValue.address);
      await tester.pump();

      expect(find.descendant(of: find.byType(ShellTopBar), matching: find.text('Address copied')), findsOneWidget);
      await tester.pump(AccountNoteNotifier.failureShownFor);
    });
  });
}
