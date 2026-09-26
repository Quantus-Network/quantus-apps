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
  final AccountDiscoveryService _discovery;

  WalletCreationService({
    SettingsService? settingsService,
    AccountsService? accountsService,
    AccountDiscoveryService? discoveryService,
  }) : _settings = settingsService ?? SettingsService(),
       _accounts = accountsService ?? AccountsService(),
       _discovery = discoveryService ?? AccountDiscoveryService(HdWalletService());

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

  /// Saves [mnemonic] for the wallet of [root], records the wallet's pending
  /// account scan and inserts [root]. The scan is recorded before the insert
  /// so an app stopped right after the insert still finishes the scan on its
  /// next start. A failed insert leaves no pending scan behind; the mnemonic
  /// is not deleted, since at an index already in use it is the existing
  /// wallet's. Dev seeds have no on-chain accounts to scan.
  Future<void> importWallet({required String mnemonic, required Account root}) async {
    final walletIndex = root.walletIndex;
    await _settings.setMnemonic(mnemonic, walletIndex);
    if (HdWalletService.isDevAccount(mnemonic)) return _accounts.addAccount(root);
    await _settings.setPendingAccountScan(walletIndex, root.accountId);
    try {
      await _accounts.addAccount(root);
    } catch (_) {
      await _settings.setPendingAccountScan(walletIndex, null);
      rethrow;
    }
  }

  /// Adds every on-chain account of [mnemonic] to [walletIndex]: both
  /// signature schemes, any derivation index. [rootAccountId] is the wallet's
  /// root added on import; when it has no history but funded accounts were
  /// found, the first of them becomes active so a returning user lands on it.
  ///
  /// A failed scan is handed to [onScanFailed]; the scan runs again while it
  /// answers true and stops once it answers false. The pending scan recorded
  /// by [importWallet] is cleared once a scan finishes; until then
  /// [resumePendingAccountScans] can complete it.
  Future<void> discoverImportedAccounts({
    required String mnemonic,
    required int walletIndex,
    required String rootAccountId,
    required Future<bool> Function(Object error) onScanFailed,
  }) async {
    await _finishPendingScan(
      mnemonic: mnemonic,
      walletIndex: walletIndex,
      scan: rootAccountId,
      defaultAccountId: rootAccountId,
      activeBefore: await _activeAccountId(),
      onScanFailed: onScanFailed,
    );
  }

  /// The scan runs while the user can act. Wallet removal clears the pending
  /// scan first and a later import at the same index records another one, so
  /// [scan] is checked before every write, and the active account is only
  /// switched when it is still [activeBefore], the one selected when the scan
  /// started.
  Future<void> _finishPendingScan({
    required String mnemonic,
    required int walletIndex,
    required String scan,
    required String? defaultAccountId,
    required String? activeBefore,
    required Future<bool> Function(Object error) onScanFailed,
  }) async {
    bool superseded() {
      if (_settings.pendingAccountScan(walletIndex) == scan) return false;
      quantusPrint('Wallet $walletIndex was removed during its account scan');
      return true;
    }

    while (true) {
      try {
        final discovered = await _discovery.discoverAccounts(mnemonic: mnemonic, walletIndex: walletIndex);
        if (superseded()) return;
        final existing = (await _accounts.getAccounts()).map((a) => a.accountId).toSet();
        var count = existing.length;
        for (final account in discovered.where((a) => !existing.contains(a.accountId))) {
          if (superseded()) return;
          await _accounts.addAccount(account.copyWith(name: 'Account ${++count}'));
        }
        if (defaultAccountId != null &&
            discovered.isNotEmpty &&
            !discovered.any((a) => a.accountId == defaultAccountId) &&
            await _activeAccountId() == activeBefore) {
          if (superseded()) return;
          await _settings.setActiveAccount(RegularAccount(discovered.first));
        }
        if (superseded()) return;
        await _settings.setPendingAccountScan(walletIndex, null);
        return;
      } catch (e) {
        if (!await onScanFailed(e)) return;
      }
    }
  }

  Future<String?> _activeAccountId() async => (await _settings.getActiveAccount())?.account.accountId;

  /// Finishes the import scan of every wallet in [accounts] whose scan was
  /// skipped or interrupted, so accounts missed while the indexer was
  /// unreachable still appear. As on import, an active transparent account of
  /// that wallet with no history gives way to the first funded account found.
  /// Returns whether any scan finished. A scan that fails again stays pending
  /// for the next call.
  Future<bool> resumePendingAccountScans(Iterable<Account> accounts) async {
    var finished = false;
    final active = (await _settings.getActiveAccount())?.account;
    for (final walletIndex in accounts.map((a) => a.walletIndex).toSet()) {
      final scan = _settings.pendingAccountScan(walletIndex);
      if (scan == null) continue;
      final mnemonic = await _settings.getMnemonic(walletIndex);
      if (mnemonic == null) throw StateError('Wallet $walletIndex has a pending account scan but no mnemonic');
      final activeHere =
          active is Account && active.walletIndex == walletIndex && active.accountType == AccountType.local;
      await _finishPendingScan(
        mnemonic: mnemonic,
        walletIndex: walletIndex,
        scan: scan,
        defaultAccountId: activeHere ? active.accountId : null,
        activeBefore: active?.accountId,
        onScanFailed: (e) async {
          quantusPrint('Resumed account scan of wallet $walletIndex failed: $e');
          return false;
        },
      );
      finished = finished || _settings.pendingAccountScan(walletIndex) == null;
    }
    return finished;
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
  unawaited(
    registerForRemoteNotificationsBestEffort(ref.read, insertAddress: walletIndex > 0 ? account.accountId : null),
  );
  return account;
}
