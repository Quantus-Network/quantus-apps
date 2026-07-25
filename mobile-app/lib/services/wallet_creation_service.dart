import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';

class WalletCreationService {
  final SettingsService _settings;
  final AccountsService _accounts;
  final ReferralService _referral;

  WalletCreationService({
    SettingsService? settingsService,
    AccountsService? accountsService,
    ReferralService? referralService,
  }) : _settings = settingsService ?? SettingsService(),
       _accounts = accountsService ?? AccountsService(),
       _referral = referralService ?? ReferralService();

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
    required List<Account> existingAccounts,
  }) async {
    await _settings.setMnemonic(mnemonic, walletIndex);

    final hasRoot = existingAccounts.any((a) => a.walletIndex == walletIndex && a.index == 0);
    if (!hasRoot) {
      _settings.setWalletOrigin(walletIndex, WalletOrigin.created);
      final account = Account(walletIndex: walletIndex, index: 0, name: name, accountId: accountId);
      await _accounts.addAccount(account);
      unawaited(_referral.submitAddressToBackend());
      return account;
    }

    return existingAccounts.firstWhere((a) => a.walletIndex == walletIndex && a.index == 0);
  }
}
