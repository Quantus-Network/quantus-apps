import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';

class CreatedWalletDetails {
  const CreatedWalletDetails({
    required this.accountId,
    required this.accountName,
    required this.checksumPhrase,
  });

  final String accountId;
  final String accountName;
  final String checksumPhrase;
}

class WalletCreationService {
  final SettingsService _settings;
  final AccountsService _accounts;
  final ReferralService _referral;

  WalletCreationService({
    SettingsService? settingsService,
    AccountsService? accountsService,
    ReferralService? referralService,
    SubstrateService? substrateService,
    HdWalletService? hdWalletService,
    HumanReadableChecksumService? checksumService,
  }) : _settings = settingsService ?? SettingsService(),
       _accounts = accountsService ?? AccountsService(),
       _referral = referralService ?? ReferralService(),
       _substrate = substrateService ?? SubstrateService(),
       _hdWallet = hdWalletService ?? HdWalletService(),
       _checksum = checksumService ?? HumanReadableChecksumService();

  final SubstrateService _substrate;
  final HdWalletService _hdWallet;
  final HumanReadableChecksumService _checksum;

  /// Generates a mnemonic, persists the wallet, and returns display metadata.
  Future<CreatedWalletDetails> createWalletWithGeneratedMnemonic({
    required List<Account> existingAccounts,
    String accountName = 'Account 1',
    int walletIndex = 0,
  }) async {
    final mnemonic = await _substrate.generateMnemonic();
    if (mnemonic.isEmpty) {
      throw Exception('Mnemonic generation returned empty.');
    }

    final accountId = _hdWallet.keyPairAtIndex(mnemonic, 0).ss58Address;
    final checksumPhrase = await _checksum.getHumanReadableName(accountId);

    await createNewWallet(
      name: accountName,
      mnemonic: mnemonic,
      walletIndex: walletIndex,
      accountId: accountId,
      existingAccounts: existingAccounts,
    );

    return CreatedWalletDetails(
      accountId: accountId,
      accountName: accountName,
      checksumPhrase: checksumPhrase,
    );
  }

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
      final account = Account(walletIndex: walletIndex, index: 0, name: name, accountId: accountId);
      await _accounts.addAccount(account);
      unawaited(_referral.submitAddressToBackend());
      return account;
    }

    return existingAccounts.firstWhere((a) => a.walletIndex == walletIndex && a.index == 0);
  }
}
