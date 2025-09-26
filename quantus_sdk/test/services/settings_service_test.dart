import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Account Management Tests', () {
    late SettingsService settingsService;

    // Accounts for testing
    const account1 = Account(index: 0, name: 'Account 1', accountId: 'id_1');
    const account2 = Account(index: 1, name: 'Account 2', accountId: 'id_2');
    const account3 = Account(index: 2, name: 'Account 3', accountId: 'id_3');

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
      final activeAccount = await migrationService.getActiveAccount();

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
        () async => await settingsService.addAccount(
          account1.copyWith(accountId: 'new_id'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Account already exists'),
          ),
        ),
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

    test(
      'setActiveAccount and getActiveAccount should work correctly',
      () async {
        // Arrange
        await settingsService.initialize();
        await settingsService.saveAccounts([account1, account2]);

        // Act
        await settingsService.setActiveAccount(account2);
        final activeAccount = (await settingsService.getActiveAccount())!;

        // Assert
        expect(activeAccount.accountId, account2.accountId);
      },
    );

    test('setActiveAccount should throw for a non-existent account', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([account1]);

      // Act & Assert
      expect(
        () async => await settingsService.setActiveAccount(account2),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Account index does not exist'),
          ),
        ),
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
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cant remove last account'),
          ),
        ),
      );
    });

    test(
      'removeAccount should change active account if active is removed',
      () async {
        // Arrange
        await settingsService.initialize();
        await settingsService.saveAccounts([account1, account2, account3]);
        await settingsService.setActiveAccount(account2);

        // Act
        await settingsService.removeAccount(account2);
        final activeAccount = (await settingsService.getActiveAccount())!;

        // Assert
        // It should fall back to the first account in the remaining list
        expect(activeAccount.accountId, account1.accountId);
      },
    );

    test('getNextFreeAccountIndex should return correct next index', () async {
      // Arrange
      await settingsService.initialize();
      await settingsService.saveAccounts([
        account1,
        account3,
      ]); // Indices 0 and 2

      // Act
      final nextIndex = await settingsService.getNextFreeAccountIndex();

      // Assert
      expect(nextIndex, 3);
    });
  });
}
