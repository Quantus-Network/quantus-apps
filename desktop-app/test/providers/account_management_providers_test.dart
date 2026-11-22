import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/account_menu.dart';

import '../fakes.dart';

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
  signers: const ['qzMain', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

class _NoTelemetry implements Telemetry {
  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) {}
}

class _RecordingPush implements PushRegistration {
  final addresses = <String>[];

  @override
  Future<void> registerAddress(String address) async => addresses.add(address);

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> unregister() async {}
}

/// What the clipboard holds, or what writing it fails with.
String? _clipboard;
Object? _clipboardError;

void _recordClipboard(WidgetTester tester) {
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
}

/// A device with Main and Savings in wallet 0 (Main active), their encrypted
/// account, a Keystone account, Trading alone in wallet 2, and Team.
Future<(FakeWalletDevice, ProviderContainer)> _device(
  WidgetTester tester, {
  String innerHash = '0xinner',
  PushRegistration? push,
}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount, _encrypted]);
  device.storage.accounts.addAll([_cold, _trading]);
  device.storage.mnemonics[2] = 'trading words';
  device.storage.multisigStore.add(_team);
  final container = ProviderContainer(
    overrides: [
      ...device.overrides,
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => 'qzDeposit', innerHash: () async => innerHash),
      ),
      pushRegistrationProvider.overrideWithValue(push ?? _RecordingPush()),
      telemetryProvider.overrideWithValue(_NoTelemetry()),
    ],
  );
  // Listened to, as the sidebar does, so they load and reload at once.
  for (final provider in [accountsProvider, activeAccountProvider, multisigAccountsProvider]) {
    container.listen(provider, (_, _) {});
  }
  await tester.pump();
  return (device, container);
}

/// Lets a change's reload finish. In the app the widgets read the providers
/// each frame, which rebuilds those a change invalidated; here they are read
/// between the frames, then storage answers.
Future<void> _settle(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 3; i++) {
    container
      ..read(accountsProvider)
      ..read(activeAccountProvider)
      ..read(multisigAccountsProvider);
    await tester.pump();
  }
}

Future<List<Account>> _accountsOf(WidgetTester tester, ProviderContainer container) async {
  await _settle(tester, container);
  return container.read(accountsProvider).requireValue;
}

AccountManager _manager(ProviderContainer container) => container.read(accountManagerProvider);

/// Closes [container] as the app does when it quits, before the test ends:
/// a note's timer, and what the providers keep running, stop with it.
Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  container.dispose();
  await tester.pump();
}

void main() {
  group('copy', () {
    testWidgets('copies the address and notes it on the account for a moment', (tester) async {
      _recordClipboard(tester);
      final (_, container) = await _device(tester);

      await _manager(container).copy(savingsAccount, CopiedValue.address);

      expect(_clipboard, 'qzSavings');
      final note = container.read(accountNoteProvider);
      expect(note?.accountId, 'qzSavings');
      expect(note?.message, 'Address copied');
      expect(note?.isError, isFalse);

      await tester.pump(AccountNoteNotifier.shownFor - const Duration(milliseconds: 10));
      expect(container.read(accountNoteProvider), isNotNull);
      await tester.pump(const Duration(milliseconds: 20));
      expect(container.read(accountNoteProvider), isNull);
      await _close(tester, container);
    });

    testWidgets('copies a multisig\'s address', (tester) async {
      _recordClipboard(tester);
      final (_, container) = await _device(tester);

      await _manager(container).copy(_team, CopiedValue.address);

      expect(_clipboard, 'qzTeam');
      expect(container.read(accountNoteProvider)?.accountId, 'qzTeam');
      await _close(tester, container);
    });

    testWidgets('copies the encrypted account\'s inner hash', (tester) async {
      _recordClipboard(tester);
      final (_, container) = await _device(tester, innerHash: '0xabc');

      await _manager(container).copy(_encrypted, CopiedValue.innerHash);

      expect(_clipboard, '0xabc');
      expect(container.read(accountNoteProvider)?.message, 'Inner hash copied');
      await _close(tester, container);
    });

    testWidgets('a copy that fails is noted as a failure, for longer, and leaves the clipboard', (tester) async {
      _recordClipboard(tester);
      final (_, container) = await _device(tester);
      _clipboardError = PlatformException(code: 'busy', message: 'the clipboard is busy');

      await _manager(container).copy(savingsAccount, CopiedValue.address);

      expect(_clipboard, isNull);
      final note = container.read(accountNoteProvider);
      expect(note?.isError, isTrue);
      expect(note?.message, contains('the clipboard is busy'));

      await tester.pump(AccountNoteNotifier.shownFor + const Duration(milliseconds: 10));
      expect(container.read(accountNoteProvider), isNotNull);
      await tester.pump(AccountNoteNotifier.failureShownFor);
      expect(container.read(accountNoteProvider), isNull);
      await _close(tester, container);
    });

    testWidgets('a new note replaces the one showing, and keeps its own time', (tester) async {
      _recordClipboard(tester);
      final (_, container) = await _device(tester);

      await _manager(container).copy(savingsAccount, CopiedValue.address);
      await tester.pump(AccountNoteNotifier.shownFor - const Duration(milliseconds: 100));
      await _manager(container).copy(mainAccount, CopiedValue.address);

      expect(container.read(accountNoteProvider)?.accountId, 'qzMain');
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(accountNoteProvider)?.accountId, 'qzMain');
      await _close(tester, container);
    });
  });

  group('rename', () {
    testWidgets('stores the name trimmed and reloads the accounts', (tester) async {
      final (device, container) = await _device(tester);

      final edit = await _manager(container).rename(savingsAccount, '  Rainy day  ');

      expect(edit, const NameChanged('Rainy day'));
      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Rainy day');
      expect((await _accountsOf(tester, container)).firstWhere((a) => a.accountId == 'qzSavings').name, 'Rainy day');
      await _close(tester, container);
    });

    testWidgets('renaming the active account renames it where it is shown as active', (tester) async {
      final (_, container) = await _device(tester);

      await _manager(container).rename(mainAccount, 'Everyday');
      await _settle(tester, container);

      expect(container.read(activeAccountProvider).value?.account.name, 'Everyday');
      await _close(tester, container);
    });

    testWidgets('a blank or unchanged name writes nothing', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.writeError = StateError('nothing should be written');

      expect(await _manager(container).rename(savingsAccount, '   '), const NameBlank());
      expect(await _manager(container).rename(savingsAccount, ' Savings '), const NameUnchanged());
      await _close(tester, container);
    });

    testWidgets('a write that fails is thrown, and the name stays', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.writeError = StateError('disk full');

      await expectLater(_manager(container).rename(savingsAccount, 'Rainy day'), throwsStateError);
      expect(device.storage.accounts.firstWhere((a) => a.accountId == 'qzSavings').name, 'Savings');
      await _close(tester, container);
    });

    testWidgets('renames a multisig through the multisigs', (tester) async {
      final (device, container) = await _device(tester);

      await _manager(container).rename(_team, ' Board ');

      expect(device.storage.multisigStore.single.name, 'Board');
      expect(container.read(multisigAccountsProvider).value?.single.name, 'Board');
      await _close(tester, container);
    });
  });

  group('renameWallet', () {
    testWidgets('stores the name trimmed, and the wallet is called by it', (tester) async {
      final (device, container) = await _device(tester);
      container.listen(walletLabelProvider(2), (_, _) {});

      await _manager(container).renameWallet(2, '  Trading desk  ');
      await tester.pump();

      expect(device.storage.names[2], 'Trading desk');
      expect(container.read(walletLabelProvider(2)), 'Trading desk');
      await _close(tester, container);
    });

    testWidgets('a blank name clears it, and the wallet is called by its number again', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.names[2] = 'Trading desk';
      container.listen(walletLabelProvider(2), (_, _) {});

      await _manager(container).renameWallet(2, '   ');
      await tester.pump();

      expect(device.storage.names.containsKey(2), isFalse);
      expect(container.read(walletLabelProvider(2)), 'Wallet 2');
      await _close(tester, container);
    });

    testWidgets('the name it is shown by, unchanged, writes nothing', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.writeError = StateError('nothing should be written');

      await _manager(container).renameWallet(2, ' Wallet 2 ');
      await _manager(container).renameWallet(2, '');

      expect(device.storage.names.containsKey(2), isFalse);
      await _close(tester, container);
    });

    testWidgets('a write that fails is thrown, and the name stays', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.names[2] = 'Trading desk';
      device.storage.writeError = StateError('disk full');

      await expectLater(_manager(container).renameWallet(2, 'Day trades'), throwsStateError);
      expect(device.storage.names[2], 'Trading desk');
      await _close(tester, container);
    });
  });

  group('startRename', () {
    testWidgets('with the sidebar showing, the account is renamed there', (tester) async {
      final (_, container) = await _device(tester);

      await _manager(container).startRename(savingsAccount);

      expect(container.read(sidebarRenameProvider), const RenameAccount('qzSavings'));
      expect(container.read(shellSheetProvider), isNull);
      await _close(tester, container);
    });

    testWidgets('with the sidebar hidden, Get Info opens on its name instead', (tester) async {
      final (_, container) = await _device(tester);
      container.read(sidebarVisibleProvider.notifier).toggle();

      await _manager(container).startRename(savingsAccount);

      expect(container.read(sidebarRenameProvider), isNull);
      expect(container.read(shellSheetProvider), ShellSheet.accountInfo);
      final target = container.read(accountInfoTargetProvider);
      expect((target?.accountId, target?.start), ('qzSavings', AccountInfoStart.rename));
      await _close(tester, container);
    });

    testWidgets('a wallet is renamed in the sidebar', (tester) async {
      final (_, container) = await _device(tester);

      _manager(container).startRenameWallet(2);

      expect(container.read(sidebarRenameProvider), const RenameWallet(2));
      await _close(tester, container);
    });
  });

  group('renameWallet', () {
    testWidgets('stores the name trimmed, and the wallet is called by it', (tester) async {
      final (device, container) = await _device(tester);
      container.listen(walletLabelProvider(2), (_, _) {});

      await _manager(container).renameWallet(2, '  Trading desk  ');
      await tester.pump();

      expect(device.storage.names[2], 'Trading desk');
      expect(container.read(walletLabelProvider(2)), 'Trading desk');
      await _close(tester, container);
    });

    testWidgets('a blank name clears it, and the wallet is called by its number again', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.names[2] = 'Trading desk';
      container.listen(walletLabelProvider(2), (_, _) {});

      await _manager(container).renameWallet(2, '   ');
      await tester.pump();

      expect(device.storage.names.containsKey(2), isFalse);
      expect(container.read(walletLabelProvider(2)), 'Wallet 2');
      await _close(tester, container);
    });

    testWidgets('the name it is shown by, unchanged, writes nothing', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.writeError = StateError('nothing should be written');

      await _manager(container).renameWallet(2, ' Wallet 2 ');
      await _manager(container).renameWallet(2, '');

      expect(device.storage.names.containsKey(2), isFalse);
      await _close(tester, container);
    });

    testWidgets('a write that fails is thrown, and the name stays', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.names[2] = 'Trading desk';
      device.storage.writeError = StateError('disk full');

      await expectLater(_manager(container).renameWallet(2, 'Day trades'), throwsStateError);
      expect(device.storage.names[2], 'Trading desk');
      await _close(tester, container);
    });
  });

  group('startRename', () {
    testWidgets('with the sidebar showing, the account is renamed there', (tester) async {
      final (_, container) = await _device(tester);

      await _manager(container).startRename(savingsAccount);

      expect(container.read(sidebarRenameProvider), const RenameAccount('qzSavings'));
      expect(container.read(shellSheetProvider), isNull);
      await _close(tester, container);
    });

    testWidgets('with the sidebar hidden, Get Info opens on its name instead', (tester) async {
      final (_, container) = await _device(tester);
      container.read(sidebarVisibleProvider.notifier).toggle();

      await _manager(container).startRename(savingsAccount);

      expect(container.read(sidebarRenameProvider), isNull);
      expect(container.read(shellSheetProvider), ShellSheet.accountInfo);
      final target = container.read(accountInfoTargetProvider);
      expect((target?.accountId, target?.start), ('qzSavings', AccountInfoStart.rename));
      await _close(tester, container);
    });

    testWidgets('a wallet is renamed in the sidebar', (tester) async {
      final (_, container) = await _device(tester);

      _manager(container).startRenameWallet(2);

      expect(container.read(sidebarRenameProvider), const RenameWallet(2));
      await _close(tester, container);
    });
  });

  group('createAccount', () {
    Account stored(FakeWalletDevice device, String accountId) =>
        device.storage.accounts.singleWhere((a) => a.accountId == accountId);

    testWidgets('adds the wallet\'s next account, named by the count, and makes it active', (tester) async {
      final (device, container) = await _device(tester);
      final before = device.storage.accounts.length;

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      final added = stored(device, 'qzNew2-1');
      expect((added.walletIndex, added.index, added.name), (2, 1, 'Account ${before + 1}'));
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzNew2-1');
      expect(container.read(accountsProvider).requireValue.map((a) => a.accountId), contains('qzNew2-1'));
      await _close(tester, container);
    });

    testWidgets('its name opens to be typed over in the sidebar', (tester) async {
      final (_, container) = await _device(tester);

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(container.read(sidebarRenameProvider), const RenameAccount('qzNew2-1'));
      expect(container.read(shellSheetProvider), isNull);
      await _close(tester, container);
    });

    testWidgets('with the sidebar hidden, Get Info opens on its name', (tester) async {
      final (_, container) = await _device(tester);
      container.read(sidebarVisibleProvider.notifier).toggle();

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(container.read(sidebarRenameProvider), isNull);
      expect(container.read(shellSheetProvider), ShellSheet.accountInfo);
      final target = container.read(accountInfoTargetProvider);
      expect((target?.accountId, target?.start), ('qzNew2-1', AccountInfoStart.rename));
      await _close(tester, container);
    });

    testWidgets('a closed wallet opens, and the wallet left stays open', (tester) async {
      final (_, container) = await _device(tester);
      container.listen(openWalletsProvider, (_, _) {});
      await _settle(tester, container);
      expect(container.read(openWalletsProvider), {0});

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(container.read(openWalletsProvider), {0, 2});
      await _close(tester, container);
    });

    testWidgets('a Cold Wallet is refused: nothing is added, and the active account says so', (tester) async {
      final (device, container) = await _device(tester);
      final before = List.of(device.storage.accounts);

      await _manager(container).createAccount(1);
      await _settle(tester, container);

      expect(device.storage.accounts, before);
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzMain');
      final note = container.read(accountNoteProvider);
      expect((note?.accountId, note?.message, note?.isError), ('qzMain', 'Could not add account.', true));
      await _close(tester, container);
    });

    testWidgets('one that fails adds nothing, keeps the active account, and says so on its row', (tester) async {
      final (device, container) = await _device(tester);
      final before = List.of(device.storage.accounts);
      device.storage.addAccountError = StateError('disk full');

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(device.storage.accounts, before);
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzMain');
      expect(container.read(sidebarRenameProvider), isNull);
      final note = container.read(accountNoteProvider);
      expect((note?.accountId, note?.message, note?.isError), ('qzMain', 'Could not add account.', true));
      await _close(tester, container);
    });

    testWidgets('an account added but not made active opens no name to type', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.activeWriteError = StateError('disk full');

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(stored(device, 'qzNew2-1').walletIndex, 2);
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzMain');
      expect(container.read(sidebarRenameProvider), isNull);
      expect(container.read(accountSwitchFailureProvider)?.account.account.accountId, 'qzNew2-1');
      await _close(tester, container);
    });

    testWidgets('two quick presses add two accounts in order, without clashing', (tester) async {
      final (device, container) = await _device(tester);
      final before = device.storage.accounts.length;

      await Future.wait([_manager(container).createAccount(2), _manager(container).createAccount(2)]);
      await _settle(tester, container);

      expect(stored(device, 'qzNew2-1').name, 'Account ${before + 1}');
      expect(stored(device, 'qzNew2-2').name, 'Account ${before + 2}');
      expect(container.read(accountNoteProvider), isNull);
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzNew2-2');
      await _close(tester, container);
    });

    testWidgets('nothing is added under a sheet that opened first', (tester) async {
      final (device, container) = await _device(tester);
      final before = device.storage.accounts.length;
      await container.read(shellSheetProvider.notifier).open(ShellSheet.settings);

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(device.storage.accounts, hasLength(before));
      await _close(tester, container);
    });

    testWidgets('its address is registered for notifications, once', (tester) async {
      final push = _RecordingPush();
      final (_, container) = await _device(tester, push: push);

      await _manager(container).createAccount(2);
      await _settle(tester, container);

      expect(push.addresses, ['qzNew2-1']);
      await _close(tester, container);
    });

    group('in the active account\'s wallet (⌘N)', () {
      testWidgets('goes to the wallet of the active account', (tester) async {
        final (device, container) = await _device(tester);

        await _manager(container).createInActiveWallet();
        await _settle(tester, container);

        expect(stored(device, 'qzNew0-2').walletIndex, 0);
        await _close(tester, container);
      });

      testWidgets('pressed during a switch, goes to the wallet switched to', (tester) async {
        final (device, container) = await _device(tester);

        final switching = container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(_trading));
        final creating = _manager(container).createInActiveWallet();
        await Future.wait([switching, creating]);
        await _settle(tester, container);

        expect(stored(device, 'qzNew2-1').walletIndex, 2);
        await _close(tester, container);
      });

      testWidgets('a switch that fails drops it', (tester) async {
        final (device, container) = await _device(tester);
        final before = device.storage.accounts.length;
        device.storage.activeWriteError = StateError('disk full');

        final switching = container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(_trading));
        final creating = _manager(container).createInActiveWallet();
        await Future.wait([switching, creating]);
        await _settle(tester, container);

        expect(device.storage.accounts, hasLength(before));
        await _close(tester, container);
      });

      testWidgets('with a Cold Wallet account active, does nothing', (tester) async {
        final (device, container) = await _device(tester);
        final before = device.storage.accounts.length;
        await container.read(sidebarSelectionProvider.notifier).showAccount(const RegularAccount(_cold));
        await _settle(tester, container);

        await _manager(container).createInActiveWallet();
        await _settle(tester, container);

        expect(device.storage.accounts, hasLength(before));
        expect(container.read(accountNoteProvider), isNull);
        await _close(tester, container);
      });
    });
  });

  group('disconnect', () {
    testWidgets('an account with a sibling goes alone; the active one is replaced by a non-encrypted account', (
      tester,
    ) async {
      final (device, container) = await _device(tester);

      await _manager(container).disconnect(mainAccount);
      await _settle(tester, container);

      expect(device.storage.accounts.map((a) => a.accountId), isNot(contains('qzMain')));
      expect(device.storage.mnemonics.containsKey(0), isTrue);
      expect((await _accountsOf(tester, container)).map((a) => a.accountId), isNot(contains('qzMain')));
      expect(container.read(activeAccountProvider).value?.account.accountId, 'qzSavings');
      await _close(tester, container);
    });

    testWidgets('a hardware account is removed', (tester) async {
      final (device, container) = await _device(tester);

      await _manager(container).disconnect(_cold);

      expect(device.storage.accounts.map((a) => a.accountId), isNot(contains('qzCold')));
      await _close(tester, container);
    });

    testWidgets('a wallet\'s last account takes the wallet and its recovery phrase', (tester) async {
      final (device, container) = await _device(tester);

      await _manager(container).disconnect(_trading);

      expect(device.storage.accounts.where((a) => a.walletIndex == 2), isEmpty);
      expect(device.storage.mnemonics.containsKey(2), isFalse);
      expect(device.storage.mnemonics.containsKey(0), isTrue);
      await _close(tester, container);
    });

    testWidgets('a multisig leaves the multisigs', (tester) async {
      final (device, container) = await _device(tester);

      await _manager(container).disconnect(_team);

      expect(device.storage.multisigStore, isEmpty);
      expect(container.read(multisigAccountsProvider).value, isEmpty);
      await _close(tester, container);
    });

    testWidgets('an account that cannot be disconnected is an error', (tester) async {
      final (_, container) = await _device(tester);

      await expectLater(_manager(container).disconnect(_encrypted), throwsStateError);
      await _close(tester, container);
    });

    testWidgets('a removal that fails is thrown, and nothing changes', (tester) async {
      final (device, container) = await _device(tester);
      device.storage.writeError = StateError('disk full');

      await expectLater(_manager(container).disconnect(_trading), throwsStateError);
      expect(device.storage.accounts.where((a) => a.walletIndex == 2), hasLength(1));
      expect(device.storage.mnemonics.containsKey(2), isTrue);
      await _close(tester, container);
    });
  });
}
