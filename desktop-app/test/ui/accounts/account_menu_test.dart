import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
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
Future<FakeWalletDevice> _pump(WidgetTester tester, {List<Account>? accounts}) async {
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
  }
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

    testOnMac('a software wallet\'s heading offers its recovery phrase, and opens it in Settings', (tester) async {
      await _pump(tester);
      await _rightClick(tester, find.descendant(of: find.byType(Sidebar), matching: find.text('WALLET 2')));

      expect(_menuLabels(tester), ['Show Recovery Phrase…']);
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

      expect(_menuLabels(tester), ['Show Recovery Phrase…']);
    });

    testOnMac('a Keystone wallet\'s heading has no menu', (tester) async {
      await _pump(tester);
      await _rightClick(tester, find.descendant(of: find.byType(Sidebar), matching: find.text('COLD WALLET')));

      expect(_menu, findsNothing);
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
      final field = find.descendant(of: find.byKey(AccountInfoSheet.nameFieldKey), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      Navigator.of(tester.element(find.byType(AccountInfoSheet))).pop();
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
