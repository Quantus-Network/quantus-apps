import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/sidebar_order_provider.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/disconnect_wallet_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

const _hedge = Account(walletIndex: 2, index: 1, name: 'Hedge', accountId: 'qzHedge');

/// Signed by Trading, of Wallet 2, with someone else.
final _desk = MultisigAccount(
  name: 'Desk',
  accountId: 'qzDesk',
  signers: const ['qzTrading', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzTrading',
);

/// Main (active unless [active] says) and Savings in Wallet 1, Vault in the
/// Cold Wallet, Trading and Hedge in Wallet 2, at wallet index 2, and the
/// multisig Desk, which Trading signs. Each software wallet gets its Encrypted
/// account as the window opens, unless [remoteConfig] turns them off.
Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  Account? active,
  FakeUserApproval? approval,
  RemoteConfigModel? remoteConfig,
  bool hedge = true,
}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll([vaultAccount, tradingAccount, if (hedge) _hedge]);
  device.storage.mnemonics[2] = 'trading words';
  device.storage.multisigStore.add(_desk);
  if (active != null) device.storage.activeAccount = RegularAccount(active);
  if (remoteConfig != null) device.remoteConfig = remoteConfig;
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(approval ?? FakeUserApproval()),
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

Finder _inSidebar(String text) => find.descendant(of: find.byType(Sidebar), matching: find.text(text));

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

List<MenuPanelRow> _menuRows(WidgetTester tester) =>
    tester.widgetList<MenuPanelRow>(find.descendant(of: _menu, matching: find.byType(MenuPanelRow))).toList();

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Opens the Disconnect Wallet sheet from the heading called [heading].
Future<void> _openSheet(WidgetTester tester, {String heading = 'WALLET 2'}) async {
  await _rightClick(tester, _inSidebar(heading));
  await tester.tap(find.descendant(of: _menu, matching: find.text('Disconnect Wallet…')));
  await tester.pumpAndSettle();
}

Future<void> _tick(WidgetTester tester) async {
  await tester.tap(find.byKey(DisconnectWalletSheet.backedUpKey));
  await tester.pumpAndSettle();
}

/// Whether Delete Wallet can be pressed.
bool _deleteEnabled(WidgetTester tester) {
  final button = tester.widget<QuantusButton>(
    find.descendant(of: find.byKey(DisconnectWalletSheet.deleteKey), matching: find.byType(QuantusButton)),
  );
  return button.onTap != null && !button.isDisabled && !button.isLoading;
}

Future<void> _delete(WidgetTester tester) async {
  await tester.tap(find.byKey(DisconnectWalletSheet.deleteKey));
  await tester.pumpAndSettle();
}

Iterable<Account> _inWallet2(FakeWalletDevice device) => device.storage.accounts.where((a) => a.walletIndex == 2);

void main() {
  group('where Disconnect Wallet… is offered', () {
    testOnMac('a software wallet\'s heading ends with it, alone after a separator, as a destructive item', (
      tester,
    ) async {
      await _pump(tester);
      await _rightClick(tester, _inSidebar('WALLET 2'));

      final rows = _menuRows(tester);
      expect(rows.map((row) => row.label), [
        'Rename…',
        'Show Recovery Phrase…',
        'Move Up',
        'Move Down',
        'Disconnect Wallet…',
      ]);
      expect(rows.last.isDestructive, isTrue);
      expect(rows.where((row) => row.isDestructive), hasLength(1));
      final separators = find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator));
      expect(separators, findsNWidgets(2));
      final item = find.descendant(of: _menu, matching: find.text('Disconnect Wallet…'));
      expect(tester.getTopLeft(separators.last).dy, lessThan(tester.getTopLeft(item).dy));
      expect(
        tester.getTopLeft(separators.last).dy,
        greaterThan(tester.getTopLeft(find.descendant(of: _menu, matching: find.text('Move Down'))).dy),
      );
    });

    testOnMac('the first wallet, the cold wallet and the multisigs have none', (tester) async {
      await _pump(tester);

      for (final heading in ['WALLET 1', 'COLD WALLET', 'MULTISIGS']) {
        await _rightClick(tester, _inSidebar(heading));
        expect(_menuRows(tester).map((row) => row.label), isNot(contains('Disconnect Wallet…')), reason: heading);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });

    testOnMac('the first wallet cannot be disconnected by any other way either', (tester) async {
      final device = await _pump(tester);

      await expectLater(_container(tester).read(accountManagerProvider).disconnectWallet(0), throwsStateError);
      await expectLater(_container(tester).read(accountManagerProvider).disconnectWallet(1), throwsStateError);

      expect(device.storage.accounts.map((a) => a.accountId), containsAll(['qzMain', 'qzSavings', 'qzVault']));
      expect(device.storage.mnemonics.containsKey(0), isTrue);
    });
  });

  group('the Disconnect Wallet sheet', () {
    testOnMac('names the wallet and how many accounts go, its Encrypted account counted, and Delete Wallet waits '
        'for the box', (tester) async {
      await _pump(tester);

      await _openSheet(tester);

      expect(_container(tester).read(shellSheetProvider), ShellSheet.disconnectWallet);
      expect(_inSheet(find.text('Disconnect')), findsOneWidget);
      expect(_inSheet(find.text('CANNOT BE UNDONE')), findsOneWidget);
      expect(_inSheet(find.text('This removes Wallet 2')), findsOneWidget);
      expect(_inSheet(find.text('Wallet 2’s 3 accounts leave this app')), findsOneWidget);
      expect(_inSheet(find.text('Wallet 2’s recovery phrase will be deleted from this device')), findsOneWidget);
      expect(
        _inSheet(find.text('Its funds stay on the blockchain, but only that phrase can restore them')),
        findsOneWidget,
      );
      expect(_inSheet(find.text('I’ve backed up Wallet 2’s recovery phrase')), findsOneWidget);
      expect(_deleteEnabled(tester), isFalse);

      await _tick(tester);

      expect(_deleteEnabled(tester), isTrue);
    });

    testOnMac('a wallet of one account says so in the singular', (tester) async {
      await _pump(tester, hedge: false, remoteConfig: RemoteConfigModel.fromJson({'enableEncryptedAccount': false}));

      await _openSheet(tester);

      expect(_inSheet(find.text('Wallet 2’s account leaves this app')), findsOneWidget);
    });

    testOnMac('a wallet with a name of its own is called by it', (tester) async {
      await _pump(tester);
      await _container(tester).read(accountManagerProvider).renameWallet(2, 'Trading Desk');
      await tester.pumpAndSettle();

      await _openSheet(tester, heading: 'TRADING DESK');

      expect(_inSheet(find.text('This removes Trading Desk')), findsOneWidget);
      expect(_inSheet(find.text('Trading Desk’s 3 accounts leave this app')), findsOneWidget);
      expect(_inSheet(find.text('I’ve backed up Trading Desk’s recovery phrase')), findsOneWidget);
    });

    testOnMac('ticked and approved, every account of the wallet, its phrase and its name go, and the sheet closes', (
      tester,
    ) async {
      final approval = FakeUserApproval();
      final device = await _pump(tester, approval: approval);
      await _container(tester).read(accountManagerProvider).renameWallet(2, 'Trading Desk');
      await tester.pumpAndSettle();
      expect(_inWallet2(device), hasLength(3));

      await _openSheet(tester, heading: 'TRADING DESK');
      await _tick(tester);
      await _delete(tester);

      expect(approval.reasons, ['Delete Trading Desk and its recovery phrase']);
      expect(_inWallet2(device), isEmpty);
      expect(device.storage.mnemonics.containsKey(2), isFalse);
      expect(device.storage.names.containsKey(2), isFalse);
      expect(_container(tester).read(walletNameProvider(2)), isNull);
      expect(find.byType(ShellSheetView), findsNothing);
      expect(_inSidebar('TRADING DESK'), findsNothing);
      expect(_inSidebar('Trading'), findsNothing);
      expect(_inSidebar('Hedge'), findsNothing);
      // The other wallets are as they were.
      expect(device.storage.accounts.map((a) => a.accountId), containsAll(['qzMain', 'qzSavings', 'qzVault']));
      expect(device.storage.mnemonics.containsKey(0), isTrue);
    });

    testOnMac('with the active account in it, an account of another wallet becomes active', (tester) async {
      final device = await _pump(tester, active: _hedge);
      expect(_activeId(tester), 'qzHedge');

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(_activeId(tester), 'qzMain');
      expect(device.storage.activeAccount?.account.accountId, 'qzMain');
    });

    testOnMac('with the active account elsewhere, it stays the active account', (tester) async {
      await _pump(tester, active: savingsAccount);

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(_activeId(tester), 'qzSavings');
    });

    testOnMac('where this computer cannot ask for approval, the wallet goes without a prompt', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.notSetUp;
      final device = await _pump(tester, approval: approval);

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(_inWallet2(device), isEmpty);
      expect(device.storage.mnemonics.containsKey(2), isFalse);
    });

    testOnMac('a declined or failed approval keeps the sheet open, says why, and removes nothing', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final device = await _pump(tester, approval: approval);

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(_inSheet(find.text('Deleting Wallet 2 needs your approval')), findsOneWidget);
      expect(_inWallet2(device), hasLength(3));
      expect(device.storage.mnemonics.containsKey(2), isTrue);

      approval.answer = () async => throw StateError('the prompt broke');
      await _delete(tester);

      expect(_inSheet(find.textContaining('the prompt broke')), findsOneWidget);
      expect(_inWallet2(device), hasLength(3));
      expect(device.storage.mnemonics.containsKey(2), isTrue);
    });

    testOnMac('a removal that fails says so, keeps the wallet whole, and the sheet stays', (tester) async {
      final device = await _pump(tester);

      await _openSheet(tester);
      await _tick(tester);
      device.storage.writeError = StateError('disk full');
      await _delete(tester);

      expect(_inSheet(find.text("Couldn't disconnect. Please try again.")), findsOneWidget);
      expect(_inWallet2(device), hasLength(3));
      expect(device.storage.mnemonics.containsKey(2), isTrue);
      expect(_inSidebar('WALLET 2'), findsOneWidget);
      expect(_deleteEnabled(tester), isTrue);
    });

    testOnMac('Cancel and Esc close it, and nothing changes', (tester) async {
      final approval = FakeUserApproval();
      final device = await _pump(tester, approval: approval);

      await _openSheet(tester);
      await _tick(tester);
      await tester.tap(find.byKey(DisconnectWalletSheet.cancelKey));
      await tester.pumpAndSettle();
      expect(find.byType(ShellSheetView), findsNothing);

      await _openSheet(tester);
      // Opened again, the box is not ticked.
      expect(_deleteEnabled(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ShellSheetView), findsNothing);

      expect(approval.reasons, isEmpty);
      expect(_inWallet2(device), hasLength(3));
      expect(device.storage.mnemonics.containsKey(2), isTrue);
    });

    testOnMac('its place in the sidebar and whether it was open are forgotten', (tester) async {
      await _pump(tester);
      final container = _container(tester);
      container.read(keptOpenWalletsProvider.notifier).keepOpen(2);
      container.read(sidebarGroupMoverProvider).moveBy(SidebarWallet.keyOf(2), -1);
      await tester.pumpAndSettle();
      expect(container.read(sidebarOrderProvider), contains(SidebarWallet.keyOf(2)));
      expect(container.read(keptOpenWalletsProvider), contains(2));

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(container.read(sidebarOrderProvider), isNot(contains(SidebarWallet.keyOf(2))));
      expect(container.read(keptOpenWalletsProvider), isNot(contains(2)));
    });

    testOnMac('a multisig one of its accounts signs stays, under the multisigs', (tester) async {
      final device = await _pump(tester);

      await _openSheet(tester);
      await _tick(tester);
      await _delete(tester);

      expect(device.storage.multisigStore.map((m) => m.accountId), ['qzDesk']);
      expect(_inSidebar('MULTISIGS'), findsOneWidget);
    });

    testOnMac('it does not open over another sheet', (tester) async {
      await _pump(tester);
      final container = _container(tester);
      await container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      await container.read(accountManagerProvider).openDisconnectWallet(2);
      await tester.pumpAndSettle();

      expect(container.read(shellSheetProvider), ShellSheet.settings);
      expect(find.byType(SettingsSheet), findsOneWidget);
      expect(find.byType(DisconnectWalletSheet), findsNothing);
    });

    testOnMac('it closes when its wallet is gone', (tester) async {
      await _pump(tester);
      await _openSheet(tester);

      await _container(tester).read(accountManagerProvider).disconnectWallet(2);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });
}
