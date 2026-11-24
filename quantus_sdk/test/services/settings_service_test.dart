import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../fixtures/active_swap_fixture.dart';

/// Preferences that refuse to store chosen keys, the way the Linux and
/// Windows backends answer a write the disk rejects: `false`, no error. As
/// they do, it keeps a refused value in memory, and the next write that is
/// stored puts everything in memory on the disk.
class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore() : super.empty();

  /// The keys whose writes are refused, as the app names them.
  final rejected = <String>{};

  /// The keys whose writes fail outright, as a backend that throws does.
  final failing = <String>{};

  bool _isFailing(String key) => failing.contains(key.replaceFirst('flutter.', ''));

  /// How many more writes are stored before the disk refuses every write;
  /// null when it has no such outage.
  int? storesBeforeOutage;

  /// What is in memory and not yet on the disk: a value with its type, or
  /// null for a key that was removed.
  final _unstored = <String, (String, Object)?>{};

  /// The app quits and the next one starts with a disk that stores again:
  /// what was only in memory is gone.
  void restart() {
    _unstored.clear();
    rejected.clear();
    failing.clear();
    storesBeforeOutage = null;
  }

  bool _isRejected(String key) {
    if (storesBeforeOutage case final left?) {
      if (left == 0) return true;
      storesBeforeOutage = left - 1;
    }
    return rejected.contains(key.replaceFirst('flutter.', ''));
  }

  Future<bool> _store() async {
    for (final MapEntry(:key, :value) in _unstored.entries) {
      if (value == null) {
        await super.remove(key);
      } else {
        await super.setValue(value.$1, key, value.$2);
      }
    }
    _unstored.clear();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_isFailing(key)) throw StateError('the disk is gone');
    _unstored[key] = (valueType, value);
    return _isRejected(key) ? false : _store();
  }

  @override
  Future<bool> remove(String key) async {
    if (_isFailing(key)) throw StateError('the disk is gone');
    _unstored[key] = null;
    return _isRejected(key) ? false : _store();
  }
}

/// Secure storage whose deletes fail, as a keychain that refuses one does.
class _UndeletableSecureStorage extends TestFlutterSecureStoragePlatform {
  _UndeletableSecureStorage(super.data);

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async =>
      throw PlatformException(code: 'delete-failed', message: 'The keychain refused the delete');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Account Management Tests', () {
    late SettingsService settingsService;

    // Accounts for testing
    final account1 = Account(
      walletIndex: 0,
      index: 0,
      name: 'Account 1',
      accountId: 'id_1',
      scheme: DilithiumSchemeExtension.current,
      derivationPath: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current),
    );
    final account2 = Account(
      walletIndex: 0,
      index: 1,
      name: 'Account 2',
      accountId: 'id_2',
      scheme: DilithiumSchemeExtension.current,
      derivationPath: HdWalletService.pathForIndex(1, DilithiumSchemeExtension.current),
    );
    const account3 = Account(walletIndex: 0, index: 2, name: 'Account 3', accountId: 'id_3');

    setUp(() async {
      // Reset mock storage BEFORE any SharedPreferences.getInstance() calls
      SharedPreferences.setMockInitialValues({});

      // Reset service initialization between tests so initialize() rebinds prefs
      SettingsService().resetForTest();

      // Fresh service instance for each test
      settingsService = SettingsService();
      await settingsService.initialize();
    });

    test('Migration: should migrate from old single-account format', () async {
      // Arrange: Set up old format keys directly in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account_id', 'old_id');
      await prefs.setString('wallet_name', 'Old Wallet');

      // Reset service so it re-binds to prefs and performs migration
      SettingsService().resetForTest();
      final migrationService = SettingsService();
      await migrationService.initialize();

      // Act
      final accounts = await migrationService.getAccounts();
      final activeAccount = await migrationService.getActiveRegularAccount();

      // Assert
      expect(accounts.length, 1);
      expect(accounts.first.accountId, 'old_id');
      expect(accounts.first.name, 'Old Wallet');
      expect(accounts.first.index, 0);
      expect(activeAccount, isNotNull);
      expect(activeAccount!.accountId, 'old_id');

      // Verify old keys are removed
      final verificationPrefs = await SharedPreferences.getInstance();
      expect(verificationPrefs.getString('account_id'), isNull);
      expect(verificationPrefs.getString('wallet_name'), isNull);
    });

    test('getAccounts should return empty list if no wallet exists', () async {
      // Arrange (no keys set)
      await settingsService.initialize();
      // Act
      final accounts = await settingsService.getAccounts();
      // Assert
      expect(accounts, isEmpty);
    });

    test('addAccount should add a new account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.addAccount(account1);

      // Act
      final accounts = await settingsService.getAccounts();

      // Assert
      expect(accounts.length, 1);
      expect(accounts.first.accountId, account1.accountId);
    });

    test('addAccount should throw if account index already exists', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.addAccount(account1);

      // Act & Assert
      expect(
        () async => await settingsService.addAccount(account1.copyWith(accountId: 'new_id')),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Account already exists'))),
      );
    });

    test('updateAccount should modify an existing account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.addAccount(account1);

      // Act
      final updatedAccount = account1.copyWith(name: 'Updated Name');
      await settingsService.updateAccount(updatedAccount);
      final accounts = await settingsService.getAccounts();

      // Assert
      expect(accounts.first.name, 'Updated Name');
    });

    test('updateAccount refreshes the active account snapshot after a rename', () async {
      await settingsService.saveAccounts([account1, account2]);
      await settingsService.setActiveAccount(RegularAccount(account1));

      await settingsService.updateAccount(account1.copyWith(name: 'Renamed account'));

      final active = (await settingsService.getActiveAccount())!;
      expect(active.account.name, 'Renamed account');
    });

    test('updateAccount keeps the active snapshot when another account is renamed', () async {
      await settingsService.saveAccounts([account1, account2]);
      await settingsService.setActiveAccount(RegularAccount(account1));

      await settingsService.updateAccount(account2.copyWith(name: 'Renamed account'));

      final active = (await settingsService.getActiveAccount())!;
      expect(active.account.name, account1.name);
    });

    test('updateMultisigAccount refreshes the active account snapshot after a rename', () async {
      final msig = MultisigAccount(
        name: 'Msig',
        accountId: 'msig_1',
        signers: [account1.accountId],
        threshold: 1,
        nonce: BigInt.zero,
        myMemberAccountId: account1.accountId,
      );
      await settingsService.addMultisigAccount(msig);
      await settingsService.setActiveAccount(MultisigDisplayAccount(msig));

      await settingsService.updateMultisigAccount(msig.copyWith(name: 'Renamed account'));

      final active = (await settingsService.getActiveAccount())!;
      expect(active, isA<MultisigDisplayAccount>());
      expect(active.account.name, 'Renamed account');
    });

    test('setActiveAccount and getActiveAccount should work correctly', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account2]);

      // Act
      await settingsService.setActiveAccount(RegularAccount(account2));
      final activeAccount = (await settingsService.getActiveAccount())!;

      // Assert
      expect(activeAccount.account.accountId, account2.accountId);
    });

    test('setActiveAccount should throw for a non-existent account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1]);

      // Act & Assert
      expect(
        () async => await settingsService.setActiveAccount(RegularAccount(account2)),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Account index does not exist'))),
      );
    });

    test('removeAccount should remove an account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account2]);

      // Act
      await settingsService.removeAccount(account2);
      final accounts = await settingsService.getAccounts();

      // Assert
      expect(accounts.length, 1);
      expect(accounts.first.accountId, account1.accountId);
    });

    test('removeAccount should throw if it is the last account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1]);

      // Act & Assert
      expect(
        () async => await settingsService.removeAccount(account1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Cant remove last account'))),
      );
    });

    test('removeAccount should change active account if active is removed', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account2, account3]);
      await settingsService.setActiveAccount(RegularAccount(account2));

      // Act
      await settingsService.removeAccount(account2);
      final activeAccount = (await settingsService.getActiveAccount())!;

      // Assert
      // It should fall back to the first account in the remaining list
      expect(activeAccount.account.accountId, account1.accountId);
    });

    group('preferences where active_account_id names another account than the active snapshot', () {
      setUp(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_display_account', jsonEncode(RegularAccount(account2).toJson()));
        await prefs.setString('active_account_id', account1.accountId);
      });

      test('removeAccount replaces the account the snapshot holds', () async {
        await settingsService.saveAccounts([account1, account2]);

        await settingsService.removeAccount(account2);

        expect((await settingsService.getActiveAccount())!.account.accountId, account1.accountId);
      });

      test('removeWallet replaces the account the snapshot holds', () async {
        FlutterSecureStorage.setMockInitialValues({});
        final inWallet1 = account2.copyWith(walletIndex: 1);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_display_account', jsonEncode(RegularAccount(inWallet1).toJson()));
        await settingsService.saveAccounts([account1, inWallet1]);

        await settingsService.removeWallet(1);

        expect((await settingsService.getActiveAccount())!.account.accountId, account1.accountId);
      });
    });

    test('preferences with only active_account_id still select that account, and removing it picks another', () async {
      await settingsService.saveAccounts([account1, account2]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_account_id', account2.accountId);

      expect((await settingsService.getActiveAccount())!.account.accountId, account2.accountId);

      await settingsService.removeAccount(account2);

      expect((await settingsService.getActiveAccount())!.account.accountId, account1.accountId);
    });

    test('removing a regular account while a multisig is active keeps the multisig active', () async {
      await settingsService.saveAccounts([account1, account2]);
      await settingsService.setActiveAccount(RegularAccount(account2));
      final msig = MultisigAccount(
        name: 'Msig',
        accountId: 'msig_1',
        signers: [account1.accountId],
        threshold: 1,
        nonce: BigInt.zero,
        myMemberAccountId: account1.accountId,
      );
      await settingsService.addMultisigAccount(msig);
      await settingsService.setActiveAccount(MultisigDisplayAccount(msig));

      await settingsService.removeAccount(account2);

      expect((await settingsService.getActiveAccount())!.account.accountId, msig.accountId);
    });

    test('getNextFreeAccountIndex returns 0 for an empty wallet', () async {
      await settingsService.initialize();
      expect(await settingsService.getNextFreeAccountIndex(0), 0);
    });

    test('getNextFreeAccountIndex returns max+1 when indices are contiguous', () async {
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account2, account3]); // 0, 1, 2
      expect(await settingsService.getNextFreeAccountIndex(0), 3);
    });

    test('getNextFreeAccountIndex fills the lowest gap first', () async {
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account3]); // indices 0 and 2
      expect(await settingsService.getNextFreeAccountIndex(0), 1);
    });

    test('getNextFreeAccountIndex is computed per-wallet', () async {
      await settingsService.initialize();
      await settingsService.saveAccounts([
        const Account(walletIndex: 0, index: 0, name: 'A', accountId: 'w0_0'),
        const Account(walletIndex: 1, index: 0, name: 'B', accountId: 'w1_0'),
        const Account(walletIndex: 1, index: 1, name: 'C', accountId: 'w1_1'),
      ]);
      expect(await settingsService.getNextFreeAccountIndex(0), 1);
      expect(await settingsService.getNextFreeAccountIndex(1), 2);
    });

    test('re-adding accounts reproduces the same indices in order (keep index 0 and 6)', () async {
      await settingsService.initialize();

      // Wallet with accounts at indices 0..6 (Account 1..7).
      final full = [
        for (var i = 0; i < 7; i++) Account(walletIndex: 0, index: i, name: 'Account ${i + 1}', accountId: 'id_$i'),
      ];
      await settingsService.saveAccounts(full);

      // Keep only index 0 (first) and index 6 (Account 7, which holds balance).
      await settingsService.saveAccounts([full[0], full[6]]);

      // New accounts fill 1,2,3,4,5 (skipping the used 6), then 7.
      for (final expectedIndex in [1, 2, 3, 4, 5, 7]) {
        final next = await settingsService.getNextFreeAccountIndex(0);
        expect(next, expectedIndex);
        await settingsService.addAccount(
          Account(walletIndex: 0, index: next, name: 'Account ${next + 1}', accountId: 'new_id_$next'),
        );
      }
    });

    test('re-adding accounts fills gaps when only index 0 and 5 remain', () async {
      await settingsService.initialize();
      await settingsService.saveAccounts([
        const Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'gap_id_0'),
        const Account(walletIndex: 0, index: 5, name: 'Account 6', accountId: 'gap_id_5'),
      ]);

      // Fill 1,2,3,4, skip the used 5, then 6.
      for (final expectedIndex in [1, 2, 3, 4, 6]) {
        final next = await settingsService.getNextFreeAccountIndex(0);
        expect(next, expectedIndex);
        await settingsService.addAccount(
          Account(walletIndex: 0, index: next, name: 'Account ${next + 1}', accountId: 'gap_new_$next'),
        );
      }
    });

    test('getNextFreeAccountIndex ignores the reserved encrypted account index', () async {
      // Arrange: a transparent account plus the high-index encrypted account.
      const encrypted = Account(
        walletIndex: 0,
        index: AppConstants.encryptedAccountIndex,
        name: 'Encrypted Account',
        accountId: 'id_encrypted',
        accountType: AccountType.encrypted,
      );
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, encrypted]);

      // Act
      final nextIndex = await settingsService.getNextFreeAccountIndex(0);

      // Assert: transparent indices stay contiguous (1), not 1025.
      expect(nextIndex, 1);
    });

    test('pending account scan is set, read back and cleared per wallet', () async {
      expect(settingsService.pendingAccountScan(1), isNull);
      await settingsService.setPendingAccountScan(1, 'root_w1');
      expect(settingsService.pendingAccountScan(1), 'root_w1');
      expect(settingsService.pendingAccountScan(0), isNull);
      await settingsService.setPendingAccountScan(1, null);
      expect(settingsService.pendingAccountScan(1), isNull);
    });

    test('removing a wallet clears its pending account scan', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await settingsService.saveAccounts([account1, account1.copyWith(walletIndex: 1, accountId: 'id_w1')]);
      await settingsService.setPendingAccountScan(1, 'id_w1');

      await settingsService.removeWallet(1);

      expect(settingsService.pendingAccountScan(1), isNull);
    });

    test('active swap is set, read back and cleared', () async {
      expect(settingsService.getActiveSwap(), isNull);
      final now = DateTime.utc(2026, 10, 15, 12);
      await settingsService.setActiveSwap(
        activeSwapIn(SwapStatus.processing, startedAt: now, deadline: now.add(const Duration(minutes: 20))),
      );
      final kept = settingsService.getActiveSwap()!;
      expect(kept.order.status, SwapStatus.processing);
      expect(kept.startedAt.isAtSameMomentAs(now), isTrue);
      await settingsService.clearActiveSwap();
      expect(settingsService.getActiveSwap(), isNull);
    });
  });

  group('setActiveAccount, when the account cannot be stored', () {
    const main = Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'id_main');
    const savings = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'id_savings');
    const unknown = Account(walletIndex: 0, index: 2, name: 'Unknown', accountId: 'id_unknown');

    late _RejectingStore store;
    late SettingsService settings;

    /// The settings as an app started now would read them from [store].
    Future<SettingsService> reopened() async {
      SharedPreferences.resetStatic();
      final reopened = SettingsService();
      await reopened.initialize();
      return reopened;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = _RejectingStore();
      SharedPreferencesStorePlatform.instance = store;
      settings = SettingsService();
      await settings.initialize();
      await settings.saveAccounts([main, savings]);
      await settings.setActiveAccount(const RegularAccount(main));
    });

    /// The settings as the next app reads them, started before anything this
    /// one held only in memory reached the disk.
    Future<SettingsService> restarted() {
      store.restart();
      return reopened();
    }

    /// Switches to [account], and says whether the switch was reported done.
    Future<bool> switchTo(Account account) async {
      try {
        await settings.setActiveAccount(RegularAccount(account));
        return true;
      } on Exception {
        return false;
      }
    }

    test(
      'throws when the system rejects the write of active_display_account, and Main stays the active account',
      () async {
        store.rejected.add('active_display_account');

        await expectLater(
          settings.setActiveAccount(const RegularAccount(savings)),
          throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Could not save active_display_account'))),
        );

        expect((await settings.getActiveAccount())!.account.accountId, main.accountId);
        expect((await settings.getActiveRegularAccount())!.accountId, main.accountId);

        store.rejected.clear();
        // What a later write puts on the disk is still Main.
        await settings.saveAccounts([main, savings]);
        expect((await (await reopened()).getActiveAccount())!.account.accountId, main.accountId);
      },
    );

    test('a switch does not depend on active_account_id: the selection is one write', () async {
      store.rejected.add('active_account_id');

      await settings.setActiveAccount(const RegularAccount(savings));

      expect((await settings.getActiveAccount())!.account.accountId, savings.accountId);
      expect((await (await restarted()).getActiveAccount())!.account.accountId, savings.accountId);
    });

    for (final stored in [0, 1, 2]) {
      group('when the disk stops storing after $stored writes of a switch and stays down through its rollback', () {
        setUp(() => store.storesBeforeOutage = stored);

        test('the app started next has the account the switch reported', () async {
          final reported = await switchTo(savings) ? savings : main;

          expect((await settings.getActiveAccount())!.account.accountId, reported.accountId);
          expect((await (await restarted()).getActiveAccount())!.account.accountId, reported.accountId);
        });

        test('removing Savings in the app started next leaves Main active', () async {
          await switchTo(savings);
          final next = await restarted();

          await next.removeAccount(savings);

          expect((await next.getActiveAccount())!.account.accountId, main.accountId);
          expect((await (await restarted()).getActiveAccount())!.account.accountId, main.accountId);
        });
      });
    }

    test('throws the write\'s own error when the write of active_display_account fails outright, and Main stays '
        'the active account', () async {
      store.failing.add('active_display_account');

      await expectLater(
        settings.setActiveAccount(const RegularAccount(savings)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'the disk is gone')),
      );

      expect((await settings.getActiveAccount())!.account.accountId, main.accountId);
      expect((await settings.getActiveRegularAccount())!.accountId, main.accountId);
      expect((await (await restarted()).getActiveAccount())!.account.accountId, main.accountId);
    });

    test('an account that does not exist leaves Main the active account', () async {
      await expectLater(settings.setActiveAccount(const RegularAccount(unknown)), throwsException);

      expect((await settings.getActiveAccount())!.account.accountId, main.accountId);
      expect((await (await reopened()).getActiveAccount())!.account.accountId, main.accountId);
    });

    test('once the system stores again, the account is switched and kept', () async {
      store.rejected.add('active_display_account');
      await expectLater(settings.setActiveAccount(const RegularAccount(savings)), throwsException);
      store.rejected.clear();

      await settings.setActiveAccount(const RegularAccount(savings));

      expect((await settings.getActiveAccount())!.account.accountId, savings.accountId);
      expect((await (await reopened()).getActiveAccount())!.account.accountId, savings.accountId);
    });
  });

  group('addAccount, when a write fails', () {
    const first = Account(walletIndex: 0, index: 0, name: 'First', accountId: 'id_first');
    const second = Account(walletIndex: 0, index: 1, name: 'Second', accountId: 'id_second');

    late _RejectingStore store;
    late SettingsService settings;

    /// The settings as the next app reads them, started before anything this
    /// one held only in memory reached the disk.
    Future<SettingsService> restarted() async {
      store.restart();
      SharedPreferences.resetStatic();
      final next = SettingsService();
      await next.initialize();
      return next;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = _RejectingStore();
      SharedPreferencesStorePlatform.instance = store;
      settings = SettingsService();
      await settings.initialize();
    });

    final failures = <String, void Function(String key)>{
      'rejected': (key) => store.rejected.add(key),
      'failing': (key) => store.failing.add(key),
    };

    for (final MapEntry(key: how, value: fail) in failures.entries) {
      test('a $how account list write throws and adds nothing', () async {
        fail('accounts_v5');

        await expectLater(
          settings.addAccount(first),
          throwsA(predicate((e) => e is! AccountNotActivatedException, 'not a stored account')),
        );

        expect(await settings.getAccounts(), isEmpty);
        expect(await (await restarted()).getAccounts(), isEmpty);
      });

      test('a $how account list write keeps the accounts already there', () async {
        await settings.addAccount(first);
        fail('accounts_v5');

        await expectLater(settings.addAccount(second), throwsA(anything));

        expect((await settings.getAccounts()).map((a) => a.accountId), [first.accountId]);
        expect((await (await restarted()).getAccounts()).map((a) => a.accountId), [first.accountId]);
      });

      test('a $how activation of the first account says the account was stored', () async {
        fail('active_display_account');

        await expectLater(settings.addAccount(first), throwsA(isA<AccountNotActivatedException>()));

        expect((await settings.getAccounts()).map((a) => a.accountId), [first.accountId]);
        final next = await restarted();
        expect((await next.getAccounts()).map((a) => a.accountId), [first.accountId]);
        expect((await next.getActiveAccount())?.account.accountId, first.accountId);
      });
    }
  });

  group('changing the account list, when a write fails', () {
    const first = Account(walletIndex: 0, index: 0, name: 'First', accountId: 'id_first');
    const second = Account(walletIndex: 0, index: 1, name: 'Second', accountId: 'id_second');
    const trading = Account(walletIndex: 1, index: 0, name: 'Trading', accountId: 'id_trading');

    late _RejectingStore store;
    late SettingsService settings;

    /// The settings as the next app reads them, started before anything this
    /// one held only in memory reached the disk.
    Future<SettingsService> restarted() async {
      store.restart();
      SharedPreferences.resetStatic();
      final next = SettingsService();
      await next.initialize();
      return next;
    }

    /// Stores [accounts] with [active] as the active one, while every write
    /// is still stored.
    Future<void> given(List<Account> accounts, {required Account active}) async {
      await settings.saveAccounts(accounts);
      await settings.setActiveAccount(RegularAccount(active));
    }

    Future<List<String>> idsIn(SettingsService settings) async =>
        (await settings.getAccounts()).map((a) => a.accountId).toList();

    Future<String?> activeIdIn(SettingsService settings) async =>
        (await settings.getActiveAccount())?.account.accountId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      store = _RejectingStore();
      SharedPreferencesStorePlatform.instance = store;
      settings = SettingsService();
      await settings.initialize();
    });

    final failures = <String, void Function(String key)>{
      'rejected': (key) => store.rejected.add(key),
      'failing': (key) => store.failing.add(key),
    };

    for (final MapEntry(key: how, value: fail) in failures.entries) {
      test('a $how saveAccounts throws and leaves the list as it was', () async {
        await given([first], active: first);
        fail('accounts_v5');

        await expectLater(settings.saveAccounts([first, second]), throwsA(anything));

        expect(await idsIn(settings), [first.accountId]);
        expect(await idsIn(await restarted()), [first.accountId]);
      });

      test('a $how rename throws and keeps the old name', () async {
        await given([first, second], active: first);
        fail('accounts_v5');

        await expectLater(settings.updateAccount(second.copyWith(name: 'Renamed')), throwsA(anything));

        expect((await settings.getAccounts()).last.name, 'Second');
        expect((await (await restarted()).getAccounts()).last.name, 'Second');
      });

      test('a $how active account write, renaming the active account, throws and keeps the old name', () async {
        await given([first, second], active: first);
        fail('active_display_account');

        await expectLater(settings.updateAccount(first.copyWith(name: 'Renamed')), throwsA(anything));

        expect((await settings.getAccounts()).first.name, 'First');
        expect((await settings.getActiveAccount())?.account.name, 'First');
        final next = await restarted();
        expect((await next.getAccounts()).first.name, 'First');
        expect((await next.getActiveAccount())?.account.name, 'First');
      });

      test('a $how removal throws, keeps the account, and keeps it active', () async {
        await given([first, second], active: second);
        fail('accounts_v5');

        await expectLater(settings.removeAccount(second), throwsA(anything));

        expect(await idsIn(settings), [first.accountId, second.accountId]);
        expect(await activeIdIn(settings), second.accountId);
        final next = await restarted();
        expect(await idsIn(next), [first.accountId, second.accountId]);
        expect(await activeIdIn(next), second.accountId);
      });

      test('a $how wallet removal throws and leaves the wallet whole', () async {
        await given([first, trading], active: trading);
        await settings.setMnemonic('trading phrase', 1);
        await settings.setWalletName(1, 'Trading wallet');
        await settings.setPendingAccountScan(1, trading.accountId);
        fail('accounts_v5');

        await expectLater(settings.removeWallet(1), throwsA(anything));

        for (final current in [settings, await restarted()]) {
          expect(await idsIn(current), [first.accountId, trading.accountId]);
          expect(await activeIdIn(current), trading.accountId);
          expect(await current.getMnemonic(1), 'trading phrase');
          expect(current.getWalletName(1), 'Trading wallet');
          expect(current.pendingAccountScan(1), trading.accountId);
        }
      });

      test('a $how active account write, removing the active wallet, throws and keeps its scan pending', () async {
        await given([first, trading], active: trading);
        await settings.setMnemonic('trading phrase', 1);
        await settings.setPendingAccountScan(1, trading.accountId);
        fail('active_display_account');

        await expectLater(settings.removeWallet(1), throwsA(anything));

        for (final current in [settings, await restarted()]) {
          expect(await idsIn(current), [first.accountId, trading.accountId]);
          expect(await activeIdIn(current), trading.accountId);
          expect(await current.getMnemonic(1), 'trading phrase');
          expect(current.pendingAccountScan(1), trading.accountId);
        }
      });

      test('a $how removal of the pending scan throws and leaves the wallet whole', () async {
        await given([first, trading], active: trading);
        await settings.setMnemonic('trading phrase', 1);
        await settings.setPendingAccountScan(1, trading.accountId);
        fail('pending_account_scan_1');

        await expectLater(settings.removeWallet(1), throwsA(anything));

        for (final current in [settings, await restarted()]) {
          expect(await idsIn(current), [first.accountId, trading.accountId]);
          expect(await activeIdIn(current), trading.accountId);
          expect(await current.getMnemonic(1), 'trading phrase');
          expect(current.pendingAccountScan(1), trading.accountId);
        }
      });

      test('a $how move of an old single account throws and keeps its old keys', () async {
        await store.setValue('String', 'flutter.account_id', 'id_old');
        await store.setValue('String', 'flutter.wallet_name', 'Old');
        settings = await restarted();
        fail('accounts_v5');

        await expectLater(settings.getAccounts(), throwsA(anything));

        expect((await SharedPreferences.getInstance()).getString('account_id'), 'id_old');
        final next = await restarted();
        expect(await idsIn(next), ['id_old']);
        expect((await next.getAccounts()).single.name, 'Old');
      });
    }

    test('a wallet whose phrase cannot be deleted is kept whole, and the removal throws', () async {
      await given([first, trading], active: trading);
      await settings.setMnemonic('trading phrase', 1);
      await settings.setPendingAccountScan(1, trading.accountId);
      FlutterSecureStoragePlatform.instance = _UndeletableSecureStorage(
        (FlutterSecureStoragePlatform.instance as TestFlutterSecureStoragePlatform).data,
      );

      await expectLater(settings.removeWallet(1), throwsA(isA<PlatformException>()));

      for (final current in [settings, await restarted()]) {
        expect(await idsIn(current), [first.accountId, trading.accountId]);
        expect(await activeIdIn(current), trading.accountId);
        expect(await current.getMnemonic(1), 'trading phrase');
        expect(current.pendingAccountScan(1), trading.accountId);
      }
    });
  });

  group('setString, when the system rejects the write', () {
    late _RejectingStore store;
    late SettingsService settings;

    /// The settings as an app started now would read them from [store].
    Future<SettingsService> reopened() async {
      SharedPreferences.resetStatic();
      final reopened = SettingsService();
      await reopened.initialize();
      return reopened;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = _RejectingStore();
      SharedPreferencesStorePlatform.instance = store;
      settings = SettingsService();
      await settings.initialize();
    });

    test('throws, naming the key, and the key holds what it held', () async {
      await settings.setString('shortcuts', 'old');
      store.rejected.add('shortcuts');

      await expectLater(
        settings.setString('shortcuts', 'new'),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('Could not save shortcuts'))),
      );

      expect(settings.getString('shortcuts'), 'old');
    });

    test('a key that held nothing holds nothing after', () async {
      store.rejected.add('shortcuts');

      await expectLater(settings.setString('shortcuts', 'new'), throwsException);

      expect(settings.getString('shortcuts'), isNull);
    });

    test('what a later write puts on the disk is not the text that was refused', () async {
      await settings.setString('shortcuts', 'old');
      store.rejected.add('shortcuts');
      await expectLater(settings.setString('shortcuts', 'new'), throwsException);
      store.rejected.clear();

      await settings.setString('other', 'stored');

      final read = await reopened();
      expect(read.getString('shortcuts'), 'old');
      expect(read.getString('other'), 'stored');
    });

    test('when the write fails outright, the error is its own and the key holds what it held', () async {
      await settings.setString('shortcuts', 'old');
      store.failing.add('shortcuts');

      // Putting the old text back is a write that fails too; the error
      // reported is still the first one.
      await expectLater(
        settings.setString('shortcuts', 'new'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'the disk is gone')),
      );

      expect(settings.getString('shortcuts'), 'old');
      store.failing.clear();
      await settings.setString('other', 'stored');
      expect((await reopened()).getString('shortcuts'), 'old');
    });

    test('when the write fails outright on a key that held nothing, it holds nothing after', () async {
      store.failing.add('shortcuts');

      await expectLater(settings.setString('shortcuts', 'new'), throwsStateError);

      expect(settings.getString('shortcuts'), isNull);
      expect(settings.getValue('shortcuts'), isNull);
    });

    test('a value of another type than text can be read as it is, and replaced by text', () async {
      await (await SharedPreferences.getInstance()).setInt('shortcuts', 7);

      expect(settings.getValue('shortcuts'), 7);
      // Read as text it is still an error, as it always was.
      expect(() => settings.getString('shortcuts'), throwsA(isA<TypeError>()));

      await settings.setString('shortcuts', 'new');

      expect(settings.getValue('shortcuts'), 'new');
      expect((await reopened()).getString('shortcuts'), 'new');
    });

    test('a value of another type is put back when the text meant to replace it is refused', () async {
      await (await SharedPreferences.getInstance()).setInt('shortcuts', 7);
      store.rejected.add('shortcuts');

      await expectLater(settings.setString('shortcuts', 'new'), throwsException);
      expect(settings.getValue('shortcuts'), 7);

      store.rejected.clear();
      await settings.setString('other', 'stored');
      expect((await reopened()).getValue('shortcuts'), 7);
    });

    test('getValue answers nothing for a key that holds nothing', () {
      expect(settings.getValue('shortcuts'), isNull);
    });

    test('a write the system stores is read back, now and at the next start', () async {
      await settings.setString('shortcuts', 'new');

      expect(settings.getString('shortcuts'), 'new');
      expect((await reopened()).getString('shortcuts'), 'new');
    });
  });
}
