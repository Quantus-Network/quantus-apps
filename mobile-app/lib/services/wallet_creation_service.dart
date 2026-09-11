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

  /// Saves [mnemonic] for [walletIndex], inserts its root account and makes
  /// that the active account.
  ///
  /// The root insert is the commit point: a failure up to and including it
  /// leaves nothing behind (the mnemonic is deleted again), so the caller may
  /// retry. After it the wallet exists, so the remaining writes are best-effort
  /// and only logged — surfacing them would prompt a retry that creates a
  /// second wallet.
  Future<Account> createNewWallet({
    required String name,
    required String mnemonic,
    required int walletIndex,
    required String accountId,
    required DilithiumScheme scheme,
    required String derivationPath,
  }) async {
    final account = Account(
      walletIndex: walletIndex,
      index: 0,
      name: name,
      accountId: accountId,
      scheme: scheme,
      derivationPath: derivationPath,
    );
    await _settings.setMnemonic(mnemonic, walletIndex);
    try {
      await _accounts.addAccount(account);
    } catch (_) {
      await _settings.deleteMnemonic(walletIndex);
      rethrow;
    }

    try {
      _settings.setWalletOrigin(walletIndex, WalletOrigin.created);
      // Adding an account only makes it active when it is the first one.
      await _settings.setActiveAccount(RegularAccount(account));
      await _settings.setMainnetMigrationDone();
    } catch (e) {
      quantusPrint('Wallet $walletIndex was created but finishing its setup failed: $e');
    }
    return account;
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
      );

  // Software wallets always get a companion encrypted (wormhole) account. The
  // wallet already exists at this point, and the accounts screen backfills a
  // missing one, so a failure here must not read as a failed creation.
  try {
    await ensureEncryptedAccounts(ref);
  } catch (e) {
    quantusPrint('Encrypted account backfill failed for wallet $walletIndex: $e');
  }
  invalidateAccountProviders(ref);
  ref.invalidate(walletOriginProvider(walletIndex));
  ref.invalidate(recoveryPhraseViewedProvider(walletIndex));
  unawaited(registerForRemoteNotificationsBestEffort(ref, insertAddress: walletIndex > 0 ? account.accountId : null));
  return account;
}
