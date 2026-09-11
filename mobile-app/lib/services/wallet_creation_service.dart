import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';

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
    await _settings.setMainnetMigrationDone();

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

/// Creates a software wallet on the next free wallet index from a fresh
/// mnemonic, makes its root the active account and lands on the account-ready
/// page. Failures surface as a toaster; callers only track loading state.
Future<void> createSoftwareWalletFlow(BuildContext context, WidgetRef ref) async {
  try {
    final account = await _createSoftwareWallet(ref);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AccountReadyScreen(
          accountId: account.accountId,
          accountName: account.name,
          origin: AccountReadyOverviewOrigin.walletCreated,
        ),
      ),
      (_) => false,
    );
  } catch (e) {
    quantusPrint('Wallet creation failed: $e');
    if (context.mounted) {
      context.showErrorToaster(message: ref.read(l10nProvider).createWalletRecoveryPhraseSaveError('$e'));
    }
  }
}

Future<Account> _createSoftwareWallet(WidgetRef ref) async {
  final mnemonic = await SubstrateService().generateMnemonic();
  if (mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

  final settings = ref.read(settingsServiceProvider);
  final accounts = await settings.getAccounts();
  final walletIndex = nextWalletIndex(accounts);
  const scheme = DilithiumSchemeExtension.current;
  final path = HdWalletService.pathForIndex(0, scheme);
  final account =
      await WalletCreationService(
        settingsService: settings,
        accountsService: ref.read(accountsServiceProvider),
      ).createNewWallet(
        name: 'Account ${accounts.length + 1}',
        mnemonic: mnemonic,
        walletIndex: walletIndex,
        accountId: HdWalletService().keyPairAtPath(mnemonic, path, scheme).ss58Address,
        scheme: scheme,
        derivationPath: path,
        existingAccounts: accounts,
      );
  // Adding an account only makes it active when it is the first one.
  await settings.setActiveAccount(RegularAccount(account));

  // Software wallets always get a companion encrypted (wormhole) account.
  await ensureEncryptedAccounts(ref);
  invalidateAccountProviders(ref);
  ref.invalidate(walletOriginProvider(walletIndex));
  ref.invalidate(recoveryPhraseViewedProvider(walletIndex));
  unawaited(registerForRemoteNotificationsBestEffort(ref, insertAddress: walletIndex > 0 ? account.accountId : null));
  return account;
}
