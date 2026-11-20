import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

const _cold = Account(walletIndex: 1, index: 0, name: 'Cold', accountId: 'qzCold', accountType: AccountType.keystone);
const _trading = Account(walletIndex: 2, index: 0, name: 'Trading', accountId: 'qzTrading');
const _encrypted = Account(
  walletIndex: 0,
  index: 0,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted',
  accountType: AccountType.encrypted,
);
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzOther', 'qzMain', 'qzSavings'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
  creator: 'qzSavings',
);

/// A device with Main (active) and Savings in wallet 1, their encrypted account, a
/// Keystone account, Trading alone in wallet 2, and Team; the window open on it.
Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  List<Account>? accounts,
  Future<String> Function()? innerHash,
}) async {
  final device = FakeWalletDevice()..store(accounts ?? [mainAccount, savingsAccount, _encrypted]);
  if (accounts == null) {
    device.storage.accounts.addAll([_cold, _trading]);
    device.storage.mnemonics[2] = 'trading words';
    device.storage.multisigStore.add(_team);
  }
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) =>
            FakeEncryptedAccountService(() async => 'qzDeposit', innerHash: innerHash ?? () async => '0xinner'),
      ),
    ],
  );
  return device;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Future<void> _openInfo(WidgetTester tester, BaseAccount account) async {
  await _container(tester).read(accountManagerProvider).openInfo(account);
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _row(String title) => _inSheet(find.ancestor(of: find.text(title), matching: find.byType(SettingsRow)));

Finder get _nameField =>
    find.descendant(of: find.byKey(AccountInfoSheet.nameFieldKey), matching: find.byType(EditableText));

String _nameInField(WidgetTester tester) => tester.widget<EditableText>(_nameField).controller.text;

Future<void> _typeName(WidgetTester tester, String name) async {
  await tester.tap(_nameField);
  await tester.pump();
  await tester.enterText(_nameField, name);
  await tester.pump();
}

void main() {
  group('Get Info', () {
    testOnMac('a local account: its name, its address over its checkphrase, then its wallet\'s rows', (tester) async {
      await _pump(tester);
      await _openInfo(tester, savingsAccount);

      expect(_inSheet(find.text('Account Info')), findsOneWidget);
      expect(_nameInField(tester), 'Savings');
      expect(_inSheet(find.text('qzSavings')), findsOneWidget);
      expect(_inSheet(find.text('Phrase-qzSavings')), findsOneWidget);
      expect(_inSheet(find.text('WALLET 1')), findsOneWidget);
      expect(_row('Recovery Phrase'), findsOneWidget);
      expect(_row('Disconnect Account'), findsOneWidget);
    });

    testOnMac('Copy beside the address copies it', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pump(tester);
      await _openInfo(tester, savingsAccount);

      await tester.tap(_inSheet(find.byKey(AccountInfoSheet.copyAddressKey)));
      await tester.pump();

      expect(copied, 'qzSavings');
      await tester.pump(const Duration(seconds: 3));
    });

    testOnMac('a Keystone account has no recovery phrase here, and disconnects as hardware', (tester) async {
      await _pump(tester);
      await _openInfo(tester, _cold);

      expect(_row('Recovery Phrase'), findsNothing);
      expect(_row('Disconnect Hardware Account'), findsOneWidget);
      expect(_inSheet(find.text('qzCold')), findsOneWidget);
    });

    testOnMac('the last account of the first wallet cannot be disconnected', (tester) async {
      await _pump(tester, accounts: [mainAccount, _encrypted]);
      await _openInfo(tester, mainAccount);

      expect(_row('Recovery Phrase'), findsOneWidget);
      expect(_row('Disconnect Account'), findsNothing);
    });

    testOnMac('a multisig: threshold, signers creator first with own accounts named, and its marks', (tester) async {
      await _pump(tester);
      await _openInfo(tester, _team);

      expect(_inSheet(find.text('Multisig Info')), findsOneWidget);
      expect(_inSheet(find.text('2 of 3')), findsOneWidget);
      final signers = [
        for (final id in ['qzSavings', 'qzOther', 'qzMain']) tester.getTopLeft(_inSheet(find.text(id))),
      ];
      expect(signers[0].dy, lessThan(signers[1].dy));
      expect(signers[1].dy, lessThan(signers[2].dy));
      expect(
        find.descendant(of: find.byKey(AccountInfoSheet.signerKey('qzMain')), matching: find.byType(AccountLabel)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(AccountInfoSheet.signerKey('qzOther')), matching: find.byType(AccountLabel)),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byKey(AccountInfoSheet.signerKey('qzSavings')), matching: find.text('CREATOR')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(AccountInfoSheet.signerKey('qzMain')), matching: find.text('YOU')),
        findsOneWidget,
      );
      expect(_row('Disconnect Multisig'), findsOneWidget);
    });

    testOnMac('the encrypted account: its inner hash once loaded, and nothing to rename or disconnect', (tester) async {
      final loaded = Completer<String>();
      await _pump(tester, innerHash: () => loaded.future);
      await _openInfo(tester, _encrypted);

      expect(_inSheet(find.text('Loading...')), findsOneWidget);
      loaded.complete('0xfeed');
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('0xfeed')), findsOneWidget);
      expect(_inSheet(find.byKey(AccountInfoSheet.copyInnerHashKey)), findsOneWidget);
      expect(find.byKey(AccountInfoSheet.nameFieldKey), findsNothing);
      expect(_row('Recovery Phrase'), findsNothing);
      expect(_row('Disconnect Account'), findsNothing);
    });

    testOnMac('an inner hash that cannot be read says so in its place', (tester) async {
      await _pump(tester, innerHash: () async => throw StateError('no phrase'));
      await _openInfo(tester, _encrypted);

      expect(_inSheet(find.text("Couldn't load inner hash")), findsOneWidget);
    });

    testOnMac('the sheet is about the account it opened for, not the active one', (tester) async {
      await _pump(tester);
      await _openInfo(tester, _trading);

      expect(_inSheet(find.text('Trading')), findsWidgets);
      expect(_nameInField(tester), 'Trading');
      expect(_inSheet(find.text('qzTrading')), findsOneWidget);
    });

    testOnMac('the sheet closes when its account is gone', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, _trading);

      device.storage.accounts.removeWhere((a) => a.accountId == 'qzTrading');
      _container(tester).invalidate(accountsProvider);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
    });
  });

  group('rename in the sheet', () {
    testOnMac('Return stores the name trimmed; the sidebar and the header follow', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);

      await _typeName(tester, '  Rainy day  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Rainy day');
      expect(find.descendant(of: find.byType(Sidebar), matching: find.text('Rainy day')), findsOneWidget);
      expect(find.descendant(of: find.byType(ShellSheetHeader), matching: find.text('Rainy day')), findsOneWidget);
      expect(_nameInField(tester), 'Rainy day');
    });

    testOnMac('leaving the field stores the name', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);

      await _typeName(tester, 'Rainy day');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Rainy day');
    });

    testOnMac('a blank name is not stored, and says why', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);

      await _typeName(tester, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Savings');
      expect(_inSheet(find.text("Account name can't be empty")), findsOneWidget);
    });

    testOnMac('Escape puts the name back', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);

      await _typeName(tester, 'Rainy day');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_nameInField(tester), 'Savings');
      expect(find.byType(ShellSheetView), findsOneWidget);
      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Savings');
    });

    testOnMac('an unchanged name writes nothing', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);
      device.storage.writeError = StateError('nothing should be written');

      await _typeName(tester, ' Savings ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Failed to rename account.')), findsNothing);
    });

    testOnMac('a write that fails says so and keeps what was typed', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, savingsAccount);
      device.storage.writeError = StateError('disk full');

      await _typeName(tester, 'Rainy day');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Failed to rename account.')), findsOneWidget);
      expect(_nameInField(tester), 'Rainy day');
    });

    testOnMac('a multisig is renamed', (tester) async {
      final device = await _pump(tester);
      await _openInfo(tester, _team);

      await _typeName(tester, 'Board');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(device.storage.multisigStore.single.name, 'Board');
    });
  });
}
