import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/remote_notifications_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/recovery_phrase.dart';

final walletCreationServiceProvider = Provider<WalletCreationService>((ref) {
  return WalletCreationService(
    settingsService: ref.watch(settingsServiceProvider),
    accountsService: ref.watch(accountsServiceProvider),
    discoveryService: ref.watch(accountDiscoveryServiceProvider),
  );
});

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

  /// Saves [mnemonic] and inserts [root]. The account scan is marked pending
  /// first, so an app stopped before the scan finishes it on the next start.
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

  /// Adds the on-chain accounts of [mnemonic], both schemes, and activates the
  /// first one found when the root has no history. Retries while
  /// [onScanFailed] answers true.
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

  /// Stops writing once [scan] is no longer pending (wallet removed or
  /// re-imported) and keeps any account the user selected meanwhile.
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

  /// Finishes import scans that were skipped or interrupted. Called once at
  /// app start; returns whether any scan finished.
  Future<bool> resumePendingAccountScans() async {
    var finished = false;
    final active = (await _settings.getActiveAccount())?.account;
    for (final walletIndex in (await _accounts.getAccounts()).map((a) => a.walletIndex).toSet()) {
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
/// mnemonic and makes its root the active account. Where to go next is the
/// caller's decision.
Future<Account> createSoftwareWallet(WidgetRef ref) async {
  final mnemonic = await ref.read(substrateServiceProvider).generateMnemonic();
  if (mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

  final settings = ref.read(settingsServiceProvider);
  final hdWallet = ref.read(hdWalletServiceProvider);
  final accounts = await settings.getAccounts();
  final walletIndex = nextWalletIndex(accounts);
  const scheme = DilithiumSchemeExtension.current;
  final path = HdWalletService.pathForIndex(0, scheme);
  final account = await ref
      .read(walletCreationServiceProvider)
      .createNewWallet(
        name: 'Account ${accounts.length + 1}',
        mnemonic: mnemonic,
        walletIndex: walletIndex,
        accountId: hdWallet.addressOf(hdWallet.keyPairAtPath(mnemonic, path, scheme)),
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

/// A recovery phrase that is not 12 or 24 words long.
class InvalidRecoveryPhraseException implements Exception {
  const InvalidRecoveryPhraseException(this.message);

  /// Why the phrase was rejected, in the app's language.
  final String message;

  /// Reads as the plain [Exception] this replaced, which the mobile app shows
  /// as it is.
  @override
  String toString() => 'Exception: $message';
}

/// Imports the software wallet of [mnemonic] as wallet [walletIndex]: checks
/// the phrase, saves it with its root account, adds the accounts found on
/// chain and records the wallet as imported. Returns the root account. Where
/// to go next is the caller's decision.
///
/// [onScanFailed] is asked whether to scan again when the chain scan fails.
/// Answering false leaves the scan pending, to be finished on a later start.
///
/// The wallet's encrypted account is restored without being waited for, so
/// the import never waits on it. It is added to [accountsProvider] only while
/// the widget behind [ref] is still mounted.
Future<Account> importSoftwareWallet(
  WidgetRef ref, {
  required String mnemonic,
  required int walletIndex,
  required Future<bool> Function(Object error) onScanFailed,
}) async {
  final phrase = mnemonic.trim();
  final accounts = ref.read(accountsProvider).value ?? <Account>[];
  final settings = ref.read(settingsServiceProvider);
  final hdWallet = ref.read(hdWalletServiceProvider);
  final creation = ref.read(walletCreationServiceProvider);
  // Read before the first await: the encrypted account is restored after the
  // widget behind [ref] may be gone.
  final telemetry = ref.read(telemetryProvider);

  // Dev seeds (//Crystal Alice etc.) skip word-count validation, but only
  // in debug builds; in release they fail normal mnemonic validation (M8).
  if (!(kDebugMode && phrase.startsWith('//'))) {
    final words = recoveryPhraseWords(phrase);
    if (words.length != 12 && words.length != 24) {
      throw InvalidRecoveryPhraseException(ref.read(l10nProvider).importWalletValidationError);
    }
  }

  const scheme = DilithiumSchemeExtension.current;
  final path = HdWalletService.pathForIndex(0, scheme);
  final key = hdWallet.keyPairAtPath(phrase, path, scheme);
  final root = Account(
    walletIndex: walletIndex,
    index: 0,
    name: 'Account ${accounts.length + 1}',
    accountId: hdWallet.addressOf(key),
    scheme: key.scheme,
    derivationPath: path,
  );
  await creation.importWallet(mnemonic: phrase, root: root);

  if (!HdWalletService.isDevAccount(phrase)) {
    // Adds the on-chain accounts of both signature schemes. Multisigs are
    // added manually via Add Account → Discover Multisig.
    await creation.discoverImportedAccounts(
      mnemonic: phrase,
      walletIndex: walletIndex,
      rootAccountId: root.accountId,
      onScanFailed: (error) {
        quantusPrint('error discovering accounts: $error');
        telemetry.sendError('Error discovering accounts', error: error);
        return onScanFailed(error);
      },
    );
    invalidateAccountProviders(ref);
    unawaited(_restoreEncryptedAccount(ref, walletIndex, telemetry));
  }
  invalidateAccountProviders(ref);
  settings.setReferralCheckCompleted();
  settings.setExistingUserSeenPromoVideo();
  await settings.setMainnetMigrationDone();
  settings.setWalletOrigin(walletIndex, WalletOrigin.imported);
  ref.invalidate(walletOriginProvider(walletIndex));

  unawaited(registerForRemoteNotificationsBestEffort(ref.read, insertAddress: walletIndex > 0 ? root.accountId : null));
  return root;
}

/// Restores the wallet's encrypted account and warms its wormhole address
/// discovery, so UTXOs across receive and change addresses are already found
/// when the user first opens it.
Future<void> _restoreEncryptedAccount(WidgetRef ref, int walletIndex, Telemetry telemetry) async {
  try {
    final created = await ensureEncryptedAccounts(ref);
    if (!created || !ref.context.mounted) return;
    ref.invalidate(accountsProvider);
    await ref.read(encryptedStateProvider(walletIndex).future);
  } catch (e) {
    quantusPrint('encrypted discovery after import failed: $e');
    telemetry.sendError('Encrypted discovery after import failed', error: e);
  }
}
