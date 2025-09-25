import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService Account Management Tests', () {
    late SettingsService settingsService;

    // Accounts for testing
    const account1 = Account(index: 0, name: 'Account 1', accountId: 'id_1');
    const account2 = Account(index: 1, name: 'Account 2', accountId: 'id_2');
    const account3 = Account(index: 2, name: 'Account 3', accountId: 'id_3');

    setUp(() async {
      // Set up mock values for SharedPreferences
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.initialize();
    });

    test('addAccount should add a new account', () async {
      // Arrange
      await settingsService.addAccount(account1);

      // Act
      final accounts = settingsService.getAccounts();

      // Assert
      expect(accounts.length, 1);
      expect(accounts.first.accountId, account1.accountId);
    });

    test('addAccount should throw if account index already exists', () async {
      // Arrange
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
      await settingsService.addAccount(account1);

      // Act
      final updatedAccount = account1.copyWith(name: 'Updated Name');
      await settingsService.updateAccount(updatedAccount);
      final accounts = settingsService.getAccounts();

      // Assert
      expect(accounts.first.name, 'Updated Name');
    });

    test(
      'setActiveAccount and getActiveAccount should work correctly',
      () async {
        // Arrange
        await settingsService.saveAccounts([account1, account2]);

        // Act
        await settingsService.setActiveAccount(account2);
        final activeAccount = settingsService.getActiveAccount()!;

        // Assert
        expect(activeAccount.accountId, account2.accountId);
      },
    );

    test('setActiveAccount should throw for a non-existent account', () async {
      // Arrange
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
      await settingsService.saveAccounts([account1, account2]);

      // Act
      await settingsService.removeAccount(account2);
      final accounts = settingsService.getAccounts();

      // Assert
      expect(accounts.length, 1);
      expect(accounts.first.accountId, account1.accountId);
    });

    test('removeAccount should throw if it is the last account', () async {
      // Arrange
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
        await settingsService.saveAccounts([account1, account2, account3]);
        await settingsService.setActiveAccount(account2);

        // Act
        await settingsService.removeAccount(account2);
        final activeAccount = settingsService.getActiveAccount()!;

        // Assert
        // It should fall back to the first account in the remaining list
        expect(activeAccount.accountId, account1.accountId);
      },
    );

    test('getNextFreeAccountIndex should return correct next index', () async {
      // Arrange
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
