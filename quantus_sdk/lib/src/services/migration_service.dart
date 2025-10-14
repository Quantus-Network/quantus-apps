import 'dart:typed_data';

import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/settings_service.dart';

class MigrationService {
  final SettingsService _settingsService;
  final HdWalletService _hdWalletService;

  MigrationService(this._settingsService, this._hdWalletService);

  /// Check if migration is needed (old accounts exist)
  bool needsMigration() {
    return _settingsService.hasOldAccounts();
  }

  /// Get migration data including old accounts with their public keys
  Future<List<MigrationAccountData>> getMigrationData() async {
    final oldAccounts = _settingsService.getOldAccounts();
    final mnemonic = await _settingsService.getMnemonic();

    if (mnemonic == null) {
      throw Exception('No mnemonic found for migration');
    }

    final migrationData = <MigrationAccountData>[];

    for (final account in oldAccounts) {
      final keypair = _hdWalletService.keyPairAtIndex(mnemonic, account.index);
      final publicKeyHex = _uint8ListToHex(keypair.publicKey);

      migrationData.add(
        MigrationAccountData(
          oldAccount: account,
          publicKeyHex: publicKeyHex,
          newAccountId: crypto.toAccountId(obj: keypair),
        ),
      );
    }

    return migrationData;
  }

  /// Perform the migration by creating new accounts and clearing old data
  Future<void> performMigration(
    List<MigrationAccountData> migrationData,
  ) async {
    // Create new accounts with the same indices and names
    for (final data in migrationData) {
      print(
        'performMigration: \nold index: ${data.oldAccount.index} \nold name: ${data.oldAccount.name} \nold accountId: ${data.oldAccount.accountId} \nnew accountId: ${data.newAccountId}',
      );

      final newAccount = Account(
        index: data.oldAccount.index,
        name: data.oldAccount.name,
        accountId: data.newAccountId,
      );

      await _settingsService.addAccount(newAccount);
    }

    // Clear old accounts data
    await _settingsService.clearOldAccounts();
  }

  String _uint8ListToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class MigrationAccountData {
  final Account oldAccount;
  final String publicKeyHex;
  final String newAccountId;

  const MigrationAccountData({
    required this.oldAccount,
    required this.publicKeyHex,
    required this.newAccountId,
  });
}
