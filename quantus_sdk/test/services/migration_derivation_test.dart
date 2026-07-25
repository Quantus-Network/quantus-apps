@Tags(['native'])
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  late SettingsService settings;
  late MigrationService service;
  final hdWallet = HdWalletService();

  Future<void> seedOldAccounts(List<Account> accounts) async {
    await settings.setOldAccountsData(jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'mnemonic': _mnemonic});
    settings = SettingsService();
    await settings.initialize();
    service = MigrationService(settings, hdWallet);
  });

  group('MigrationService.getMigrationData', () {
    test('derives transparent accounts from their wallet mnemonic and index', () async {
      const old = Account(walletIndex: 0, index: 0, name: 'A', accountId: 'old_a');
      await seedOldAccounts([old]);

      final results = await service.getMigrationData();

      final success = results.single as MigrationSuccess;
      expect(success.newAccountId, crypto.toAccountId(obj: hdWallet.keyPairAtIndex(_mnemonic, 0)));
    });

    test('index-flagged wormhole accounts derive via the wormhole path and are typed encrypted', () async {
      // Legacy data may carry the reserved index without an accountType.
      const old = Account(
        walletIndex: 0,
        index: AppConstants.encryptedAccountIndex,
        name: 'Wormhole',
        accountId: 'old_wormhole',
      );
      await seedOldAccounts([old]);

      final results = await service.getMigrationData();

      final success = results.single as MigrationSuccess;
      expect(success.newAccountId, hdWallet.deriveWormholeKeyPair(mnemonic: _mnemonic).address);
      // Normalized so the Supabase upload and Senoti filters exclude it.
      expect(success.oldAccount.accountType, AccountType.encrypted);
    });

    test('accounts of a wallet with no mnemonic become failures', () async {
      const old = Account(walletIndex: 1, index: 0, name: 'B', accountId: 'old_b');
      await seedOldAccounts([old]);

      final results = await service.getMigrationData();

      final failure = results.single as MigrationFailure;
      expect(failure.reason, contains('wallet 1'));
    });
  });
}
