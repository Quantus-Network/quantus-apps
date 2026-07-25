import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Account Management Tests', () {
    late SettingsService settingsService;

    // Accounts for testing
    const account1 = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'id_1');
    const account2 = Account(walletIndex: 0, index: 1, name: 'Account 2', accountId: 'id_2');
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

    test('setActiveAccount and getActiveAccount should work correctly', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1, account2]);

      // Act
      await settingsService.setActiveAccount(const RegularAccount(account2));
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
        () async => await settingsService.setActiveAccount(const RegularAccount(account2)),
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
      await settingsService.setActiveAccount(const RegularAccount(account2));

      // Act
      await settingsService.removeAccount(account2);
      final activeAccount = (await settingsService.getActiveAccount())!;

      // Assert
      // It should fall back to the first account in the remaining list
      expect(activeAccount.account.accountId, account1.accountId);
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
  });
}
