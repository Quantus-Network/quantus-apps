import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late MigrationService service;

  const oldA = Account(walletIndex: 0, index: 0, name: 'A', accountId: 'old_a');
  const oldB = Account(walletIndex: 1, index: 0, name: 'B', accountId: 'old_b');

  const successA = MigrationSuccess(oldAccount: oldA, publicKeyHex: 'hex_a', newAccountId: 'new_a');
  const failureB = MigrationFailure(oldAccount: oldB, reason: 'No mnemonic found for wallet 1');

  Future<void> seedOldAccounts(List<Account> accounts) async {
    await settings.setOldAccountsData(jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.initialize();
    service = MigrationService(settings, HdWalletService());
  });

  group('MigrationService.performMigration', () {
    test('full success saves accounts, sets active account and clears old accounts', () async {
      await seedOldAccounts([oldA]);

      final failures = await service.performMigration([successA]);

      expect(failures, isEmpty);
      expect((await settings.getAccounts()).map((a) => a.accountId), ['new_a']);
      expect((await settings.getActiveRegularAccount())?.accountId, 'new_a');
      expect(settings.hasOldAccounts(), isFalse);
    });

    test('partial failure reports failures and keeps old accounts for retry', () async {
      await seedOldAccounts([oldA, oldB]);

      final failures = await service.performMigration([successA, failureB]);

      expect(failures.map((f) => f.oldAccount.accountId), ['old_b']);
      expect((await settings.getAccounts()).map((a) => a.accountId), ['new_a']);
      expect(settings.hasOldAccounts(), isTrue);
    });

    test('retry merges by accountId and never wipes accounts created in between', () async {
      await seedOldAccounts([oldA, oldB]);
      await service.performMigration([successA, failureB]);

      // User creates an account between the failed attempt and the retry.
      const created = Account(walletIndex: 0, index: 1, name: 'Created', accountId: 'created_id');
      await settings.addAccount(created);
      await settings.setActiveAccount(const RegularAccount(created));

      final failures = await service.performMigration([successA, failureB]);

      expect(failures, hasLength(1));
      final ids = (await settings.getAccounts()).map((a) => a.accountId).toList();
      expect(ids, containsAll(['new_a', 'created_id']));
      expect(ids.where((id) => id == 'new_a'), hasLength(1));
      expect((await settings.getActiveRegularAccount())?.accountId, 'created_id');
    });

    test('all-failure migration saves nothing and keeps old accounts', () async {
      await seedOldAccounts([oldB]);

      final failures = await service.performMigration([failureB]);

      expect(failures, hasLength(1));
      expect(await settings.getAccounts(), isEmpty);
      expect(settings.hasOldAccounts(), isTrue);
    });
  });
}
