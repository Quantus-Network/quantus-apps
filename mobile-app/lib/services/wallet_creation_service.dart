import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';

class WalletCreationService {
  final SettingsService _settings;
  final AccountsService _accounts;

  WalletCreationService({SettingsService? settingsService, AccountsService? accountsService})
    : _settings = settingsService ?? SettingsService(),
      _accounts = accountsService ?? AccountsService();

  /// Saves [mnemonic] for [walletIndex], adds the root account when missing,
  /// and runs referral registration for brand-new roots.
  ///
  /// Returns the root [Account] row to use after persistence (newly created or
  /// already present).
  Future<Account> createNewWallet({
    required String name,
    required String mnemonic,
    required int walletIndex,
    required String accountId,
    required DilithiumScheme scheme,
    required String derivationPath,
    required List<Account> existingAccounts,
  }) async {
    await _settings.setMnemonic(mnemonic, walletIndex);

    final hasRoot = existingAccounts.any((a) => a.walletIndex == walletIndex && a.index == 0);
    if (!hasRoot) {
      _settings.setWalletOrigin(walletIndex, WalletOrigin.created);
      final account = Account(
        walletIndex: walletIndex,
        index: 0,
        name: name,
        accountId: accountId,
        scheme: scheme,
        derivationPath: derivationPath,
      );
      await _accounts.addAccount(account);
      return account;
    }

    return existingAccounts.firstWhere((a) => a.walletIndex == walletIndex && a.index == 0);
  }
}
