import 'dart:convert';
import 'dart:typed_data';

import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/display_account.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/settings_service.dart';

/// Result of attempting to migrate an account.
sealed class MigrationResult {
  final Account oldAccount;
  const MigrationResult(this.oldAccount);
}

/// Successfully migrated account with new derived address.
class MigrationSuccess extends MigrationResult {
  final String publicKeyHex;
  final String newAccountId;

  const MigrationSuccess({required Account oldAccount, required this.publicKeyHex, required this.newAccountId})
    : super(oldAccount);
}

/// Account that cannot be migrated due to missing mnemonic or other error.
class MigrationFailure extends MigrationResult {
  final String reason;

  const MigrationFailure({required Account oldAccount, required this.reason}) : super(oldAccount);
}

class MigrationService {
  final SettingsService _settingsService;
  final HdWalletService _hdWalletService;

  MigrationService(this._settingsService, this._hdWalletService);

  /// Check if migration is needed (old accounts exist)
  bool needsMigration() {
    return _settingsService.hasOldAccounts();
  }

  /// Get migration data including old accounts with their public keys.
  ///
  /// Each result is either a [MigrationSuccess] with the derived address or a
  /// [MigrationFailure] (e.g. missing mnemonic). Uses the correct mnemonic and
  /// derivation path for each account's [Account.walletIndex] and
  /// [Account.accountType].
  Future<List<MigrationResult>> getMigrationData() async {
    final oldAccounts = _settingsService.getOldAccounts();
    final migrationResults = <MigrationResult>[];

    final mnemonicCache = <int, String?>{};

    for (final rawAccount in oldAccounts) {
      // Normalize the account type so every downstream check (derivation,
      // upload filters, saved account type) agrees on what is a wormhole
      // account.
      final isWormhole =
          rawAccount.accountType == AccountType.encrypted || rawAccount.index == AppConstants.encryptedAccountIndex;
      final account = isWormhole ? rawAccount.copyWith(accountType: AccountType.encrypted) : rawAccount;
      try {
        final walletIndex = account.walletIndex;
        if (!mnemonicCache.containsKey(walletIndex)) {
          mnemonicCache[walletIndex] = await _settingsService.getMnemonic(walletIndex);
        }
        final mnemonic = mnemonicCache[walletIndex];

        if (mnemonic == null) {
          migrationResults.add(
            MigrationFailure(oldAccount: account, reason: 'No mnemonic found for wallet $walletIndex'),
          );
          continue;
        }

        final String publicKeyHex;
        final String newAccountId;

        if (isWormhole) {
          final wormholeKeyPair = _hdWalletService.deriveWormholeKeyPair(mnemonic: mnemonic, index: 0);
          publicKeyHex = wormholeKeyPair.addressHex.replaceFirst('0x', '');
          newAccountId = wormholeKeyPair.address;
        } else {
          final keypair = _hdWalletService.keyPairAtIndex(mnemonic, account.index);
          publicKeyHex = _uint8ListToHex(keypair.publicKey);
          newAccountId = crypto.toAccountId(obj: keypair);
        }

        migrationResults.add(
          MigrationSuccess(oldAccount: account, publicKeyHex: publicKeyHex, newAccountId: newAccountId),
        );
      } catch (e) {
        migrationResults.add(MigrationFailure(oldAccount: account, reason: 'Derivation error: $e'));
      }
    }

    return migrationResults;
  }

  /// Perform the migration by creating new accounts and clearing old data.
  ///
  /// Only [MigrationSuccess] results are migrated. Old accounts are only
  /// cleared when every account migrated successfully, preventing data loss.
  ///
  /// Returns the list of accounts that failed to migrate (if any).
  Future<List<MigrationFailure>> performMigration(List<MigrationResult> migrationResults) async {
    final newAccounts = <Account>[];
    final failures = <MigrationFailure>[];

    for (final result in migrationResults) {
      switch (result) {
        case MigrationSuccess(:final oldAccount, :final newAccountId):
          print(
            'performMigration: \n'
            '  walletIndex: ${oldAccount.walletIndex} \n'
            '  old index: ${oldAccount.index} \n'
            '  old name: ${oldAccount.name} \n'
            '  old accountId: ${oldAccount.accountId} \n'
            '  accountType: ${oldAccount.accountType} \n'
            '  new accountId: $newAccountId',
          );

          newAccounts.add(
            Account(
              walletIndex: oldAccount.walletIndex,
              index: oldAccount.index,
              name: oldAccount.name,
              accountId: newAccountId,
              accountType: oldAccount.accountType,
            ),
          );

        case MigrationFailure(:final oldAccount, :final reason):
          print(
            'performMigration SKIPPED: \n'
            '  walletIndex: ${oldAccount.walletIndex} \n'
            '  index: ${oldAccount.index} \n'
            '  name: ${oldAccount.name} \n'
            '  reason: $reason',
          );
          failures.add(result);
      }
    }

    if (newAccounts.isNotEmpty) {
      // Merge by accountId so a retried migration never wipes accounts
      // created since the last attempt.
      final existing = await _settingsService.getAccounts();
      final existingIds = existing.map((a) => a.accountId).toSet();
      await _settingsService.saveAccounts([
        ...existing,
        ...newAccounts.where((a) => !existingIds.contains(a.accountId)),
      ]);
      if (existing.isEmpty) {
        await _settingsService.setActiveAccount(RegularAccount(newAccounts.first));
      }
    }

    // Only clear old accounts if all migrations succeeded, to prevent data loss.
    if (failures.isEmpty) {
      await _settingsService.clearOldAccounts();
    } else {
      print(
        'WARNING: ${failures.length} account(s) failed to migrate. '
        'Old accounts NOT cleared to prevent data loss.',
      );
    }

    return failures;
  }

  String _uint8ListToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Debug method to test migration
  Future<void> createDebugOldAccounts() async {
    final debugAccounts = [
      const Account(
        walletIndex: 0,
        index: -1,
        name: 'Primary Account',
        accountId: 'qznd1YWbgQrviV76psu5n8d24mHSuHtAc9JmJLB42gTELksvQ',
      ),
      const Account(walletIndex: 0, index: 0, name: 'Account 0', accountId: 'debug_id_0'),
      const Account(walletIndex: 0, index: 1, name: 'Account 1', accountId: 'debug_id_1'),
      // Test multi-wallet migration
      const Account(walletIndex: 1, index: 0, name: 'Wallet 1 Account', accountId: 'debug_wallet1_id'),
      // Test encrypted account migration
      const Account(
        walletIndex: 0,
        index: AppConstants.encryptedAccountIndex,
        name: 'Encrypted Account',
        accountId: 'debug_encrypted_id',
        accountType: AccountType.encrypted,
      ),
    ];

    final jsonData = jsonEncode(debugAccounts.map((a) => a.toJson()).toList());
    await _settingsService.setOldAccountsData(jsonData);
  }
}
