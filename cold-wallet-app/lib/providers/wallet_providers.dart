import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

enum WalletStatus { initializing, needsSetup, needsMigration, locked, unlocked }

/// Outcome of a password rotation. The vault write is the commit point:
/// [changed] and [changedBiometricDisabled] both mean the new password is in
/// effect; the latter means the biometric unlock key could not be re-stored
/// and biometric unlock was turned off.
enum PasswordChangeResult { wrongPassword, changed, changedBiometricDisabled }

/// [WalletState.error] after the user dismissed the device prompt.
const unlockCancelledError = 'cancelled';

@immutable
class WalletState {
  final WalletStatus status;
  final String? mnemonic;
  final List<ColdAccount> accounts;

  /// A device key entry exists, so the vault opens without a password.
  final bool biometricEnabled;
  final String? error;

  const WalletState({
    required this.status,
    this.mnemonic,
    this.accounts = const [],
    this.biometricEnabled = false,
    this.error,
  });

  WalletState copyWith({
    WalletStatus? status,
    String? mnemonic,
    List<ColdAccount>? accounts,
    bool? biometricEnabled,
    String? error,
  }) => WalletState(
    status: status ?? this.status,
    mnemonic: mnemonic ?? this.mnemonic,
    accounts: accounts ?? this.accounts,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    error: error,
  );
}

/// Injectable so a test can stand in for the platform biometric prompt.
final coldAuthServiceProvider = Provider<ColdAuthService>((ref) => ColdAuthService());

/// Injectable so a test can stand in for the Rust key derivation.
final hdWalletServiceProvider = Provider<HdWalletService>((ref) => HdWalletService());

/// Read fresh each time a screen watches it: the user can add or remove the
/// device lock between visits.
final deviceCanProtectProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(coldAuthServiceProvider).deviceCanProtect(),
);

class WalletController extends Notifier<WalletState> {
  static const _keyLostMessage =
      'This device can no longer open the wallet. Reset it and restore the key from your recovery phrase.';

  final VaultService _vault = VaultService();

  List<int>? _keyBytes;
  bool _upgradeToProtected = false;

  VaultService get vault => _vault;
  ColdAuthService get auth => ref.read(coldAuthServiceProvider);

  @override
  WalletState build() {
    _init();
    return const WalletState(status: WalletStatus.initializing);
  }

  Future<void> _init() async {
    try {
      if (!await _vault.hasWallet()) {
        state = const WalletState(status: WalletStatus.needsSetup);
        return;
      }
      final canProtect = await auth.deviceCanProtect();
      if (await _vault.restoreVaultBackupIfPresent()) {
        // A migration died between its vault write and a verified key entry:
        // the password vault is back, so any entry it left is for a vault
        // that no longer exists.
        debugPrint('Restored the vault backup of an interrupted migration');
        await _vault.deleteKeyEntry(protected: false);
        if (canProtect) await _vault.deleteKeyEntry(protected: true);
        state = const WalletState(status: WalletStatus.needsMigration);
        return;
      }
      if (await _vault.hasPlainKey()) {
        _upgradeToProtected = canProtect;
        state = const WalletState(status: WalletStatus.locked, biometricEnabled: true);
        return;
      }
      final bool protectedKey;
      try {
        protectedKey = await _vault.hasProtectedKey();
      } on VaultAccessCancelled {
        // Android prompts to open the store even for this check. The lock
        // screen prompts again, and an unlock that finds no entry re-reads
        // the wallet state.
        state = const WalletState(status: WalletStatus.locked, biometricEnabled: true);
        return;
      }
      state = WalletState(
        status: protectedKey ? WalletStatus.locked : WalletStatus.needsMigration,
        biometricEnabled: protectedKey,
      );
    } catch (e, st) {
      debugPrint('Wallet init failed reading secure storage: $e\n$st');
      state = WalletState(status: WalletStatus.initializing, error: 'Could not read secure storage.\n$e');
    }
  }

  Future<void> retryInit() async {
    state = const WalletState(status: WalletStatus.initializing);
    await _init();
  }

  /// Creates the vault under an internal random secret and keeps its derived
  /// key in the device key entry, [protected] by user presence or plain. If
  /// the entry cannot be stored (cancelled prompt or storage error) the vault
  /// is removed again and the error rethrown, so a vault without a readable
  /// key never survives creation.
  Future<void> createWallet({
    required String mnemonic,
    required List<ColdAccount> accounts,
    required bool protected,
  }) async {
    final secret = VaultService.randomSecret();
    await _vault.createVault(mnemonic: mnemonic, password: secret, accounts: accounts);
    final result = await _vault.unlockWithPassword(secret);
    try {
      await _vault.storeBiometricKey(result.keyBytes, protected: protected);
    } catch (e, st) {
      debugPrint('Create wallet: device key could not be stored, removing the vault: $e\n$st');
      await _vault.wipe();
      rethrow;
    }
    _keyBytes = result.keyBytes;
    state = WalletState(status: WalletStatus.unlocked, mnemonic: mnemonic, accounts: accounts, biometricEnabled: true);
  }

  Future<bool> unlockWithPassword(String password) async {
    try {
      final result = await _vault.unlockWithPassword(password);
      _keyBytes = result.keyBytes;
      state = state.copyWith(status: WalletStatus.unlocked, mnemonic: result.mnemonic, accounts: result.accounts);
      return true;
    } catch (e) {
      debugPrint('Password unlock failed: $e');
      return false;
    }
  }

  /// Opens the vault with the device key; the protected read is where the OS
  /// prompts. A plain entry on a device that can protect is moved behind user
  /// presence before the unlock counts, so that prompt gates it. Returns false
  /// with [WalletState.error] set: [unlockCancelledError] for a dismissed
  /// prompt, a message for a key this device can no longer release.
  Future<bool> unlockWithBiometric() async {
    try {
      final result = await _vault.unlockWithBiometricKey();
      if (_upgradeToProtected) {
        await _vault.storeBiometricKey(result.keyBytes, protected: true);
        _upgradeToProtected = false;
      }
      _keyBytes = result.keyBytes;
      state = state.copyWith(status: WalletStatus.unlocked, mnemonic: result.mnemonic, accounts: result.accounts);
      return true;
    } on VaultAccessCancelled {
      state = state.copyWith(error: unlockCancelledError);
      return false;
    } on SecretBoxAuthenticationError {
      // The vault removed a key that belonged to a previous vault; nothing
      // else can open this vault.
      debugPrint('Biometric unlock failed with a stale key; biometric unlock disabled');
      state = state.copyWith(biometricEnabled: false, error: _keyLostMessage);
      return false;
    } on StateError catch (e) {
      debugPrint('Biometric unlock found nothing to unlock with, re-reading the wallet state: $e');
      await _init();
      return false;
    } catch (e, st) {
      debugPrint('Biometric unlock failed: $e\n$st');
      state = state.copyWith(error: '$_keyLostMessage\n$e');
      return false;
    }
  }

  /// Verifies [currentPassword] against the vault, then re-encrypts the
  /// mnemonic under [newPassword]. The vault write is the commit point: any
  /// failure before it rethrows with the old password and the old biometric
  /// key both untouched, while a biometric re-store failure after it keeps
  /// the committed change and reports biometric unlock as disabled.
  Future<PasswordChangeResult> changePassword({required String currentPassword, required String newPassword}) async {
    final UnlockResult result;
    try {
      result = await _vault.unlockWithPassword(currentPassword);
    } on SecretBoxAuthenticationError {
      debugPrint('Change password: current password rejected');
      return PasswordChangeResult.wrongPassword;
    }
    final plainKey = await _vault.hasPlainKey();
    final biometric = plainKey || await _vault.hasProtectedKey();
    await _vault.createVault(mnemonic: result.mnemonic, password: newPassword, accounts: result.accounts);

    // The vault is now under a key the old one cannot open, so anything that
    // rewrites it in this session - adding an account - must use the new key.
    final fresh = await _vault.unlockWithPassword(newPassword);
    _keyBytes = fresh.keyBytes;

    if (!biometric) return PasswordChangeResult.changed;
    try {
      await _vault.storeBiometricKey(fresh.keyBytes, protected: !plainKey);
      return PasswordChangeResult.changed;
    } catch (e, st) {
      debugPrint('Change password: biometric key re-store failed, biometric unlock disabled: $e\n$st');
      try {
        // The stored key still belongs to the old vault and can no longer
        // decrypt anything; leaving it would offer a biometric unlock that
        // always fails.
        await _vault.deleteKeyEntry(protected: !plainKey);
      } catch (e2, st2) {
        debugPrint('Change password: stale biometric key could not be removed: $e2\n$st2');
      }
      state = state.copyWith(biometricEnabled: false);
      return PasswordChangeResult.changedBiometricDisabled;
    }
  }

  /// Moves a password vault to the device key: the existing rotation to an
  /// internal secret, then the key entry, with the old blob kept aside until
  /// the entry is verified readable. Returns false for a wrong password before
  /// anything is written. A cancelled prompt or a storage failure after the
  /// rotation puts the password vault back and rethrows, so the old password
  /// keeps working.
  Future<bool> migrateLegacy(String password) async {
    final UnlockResult legacy;
    try {
      legacy = await _vault.unlockWithPassword(password);
    } on SecretBoxAuthenticationError {
      debugPrint('Migration: password rejected');
      return false;
    }
    final protected = await auth.deviceCanProtect();
    await _vault.backupVaultForMigration();
    var keyAttempted = false;
    try {
      final result = await changePassword(currentPassword: password, newPassword: VaultService.randomSecret());
      if (result != PasswordChangeResult.changed) throw StateError('Migration rotation reported $result');
      final keyBytes = _keyBytes;
      if (keyBytes == null) throw StateError('Migration rotation left no key');
      keyAttempted = true;
      await _vault.storeBiometricKey(keyBytes, protected: protected);
    } catch (e, st) {
      debugPrint('Migration failed, restoring the password vault: $e\n$st');
      _keyBytes = null;
      await _vault.restoreVaultBackupIfPresent();
      if (keyAttempted) await _vault.deleteKeyEntry(protected: protected);
      rethrow;
    }
    await _vault.deleteVaultBackup();
    state = WalletState(
      status: WalletStatus.unlocked,
      mnemonic: legacy.mnemonic,
      accounts: legacy.accounts,
      biometricEnabled: true,
    );
    return true;
  }

  /// A fresh read of the device key entry, compared with the key this session
  /// unlocked with. iOS prompts; Android serves it silently inside a process
  /// that already authenticated; a plain entry answers at once. False when
  /// the prompt was dismissed.
  Future<bool> confirmPresence() async {
    final keyBytes = _keyBytes;
    if (keyBytes == null) throw StateError('Wallet is locked');
    try {
      return listEquals((await _vault.unlockWithBiometricKey()).keyBytes, keyBytes);
    } on VaultAccessCancelled {
      return false;
    }
  }

  /// Adds an account derived from the seed already in the vault.
  Future<void> addAccount(ColdAccount account) => _saveAccounts([...state.accounts, account]);

  Future<void> renameAccount(ColdAccount account, String label) {
    _requireHeld(account);
    return _saveAccounts([for (final a in state.accounts) a.derivesSameKey(account) ? a.withLabel(label) : a]);
  }

  /// Drops [account] from the vault. The seed still derives it, so adding the
  /// same derivation path again brings it back.
  Future<void> removeAccount(ColdAccount account) {
    _requireHeld(account);
    final accounts = state.accounts.where((a) => !a.derivesSameKey(account)).toList();
    if (accounts.isEmpty) throw StateError('The last account cannot be removed');
    return _saveAccounts(accounts);
  }

  void _requireHeld(ColdAccount account) {
    if (!state.accounts.any(account.derivesSameKey)) throw StateError('Account ${account.label} is not in this wallet');
  }

  Future<void> _saveAccounts(List<ColdAccount> accounts) async {
    final mnemonic = state.mnemonic;
    final keyBytes = _keyBytes;
    if (mnemonic == null || keyBytes == null) throw StateError('Wallet is locked');

    await _vault.replaceContents(
      keyBytes: keyBytes,
      contents: VaultContents(mnemonic: mnemonic, accounts: accounts),
    );
    state = state.copyWith(accounts: accounts);
  }

  void lock() {
    if (state.status != WalletStatus.unlocked) return;
    _keyBytes = null;
    state = WalletState(status: WalletStatus.locked, biometricEnabled: state.biometricEnabled);
  }

  /// The lifecycle re-lock. Android's system prompt for the protected store
  /// pauses the activity; that is not the user leaving the app.
  void lockOnBackground() {
    if (_vault.promptInProgress) return;
    lock();
  }

  Future<void> wipe() async {
    _keyBytes = null;
    _upgradeToProtected = false;
    await _vault.wipe();
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}

final walletControllerProvider = NotifierProvider<WalletController, WalletState>(WalletController.new);

/// Every account, in the order they were added to the wallet.
final accountsProvider = Provider<List<ColdAccount>>((ref) => ref.watch(walletControllerProvider).accounts);

/// Every account's address, resolved once per unlock so a scanned request can
/// be matched to the account that must sign it. Addresses only — key pairs are
/// derived at the point of use and never cached.
final addressesProvider = Provider<Map<String, ColdAccount>>((ref) {
  final mnemonic = ref.watch(walletControllerProvider).mnemonic;
  if (mnemonic == null) return const {};
  final service = HdWalletService();
  return {
    for (final account in ref.watch(accountsProvider))
      service.keyPairAtPath(mnemonic, account.derivationPath, account.scheme).ss58Address: account,
  };
});

Keypair? keypairFor(WidgetRef ref, String address) {
  final mnemonic = ref.read(walletControllerProvider).mnemonic;
  final account = ref.read(addressesProvider)[address];
  if (mnemonic == null || account == null) return null;
  return HdWalletService().keyPairAtPath(mnemonic, account.derivationPath, account.scheme);
}

/// The address of the account whose ML-DSA-65 public key is [publicKeyHex],
/// or null when no account in this wallet holds it. A NEAR transaction names
/// its key rather than a Quantus address, and the address is a hash of the
/// key, so each ML-DSA-65 account's key pair is derived and compared. Keyed
/// by hex so equal keys resolve to the same provider instance.
final nearKeyOwnerProvider = Provider.family<String?, String>((ref, publicKeyHex) {
  final mnemonic = ref.watch(walletControllerProvider).mnemonic;
  if (mnemonic == null) return null;
  final service = HdWalletService();
  for (final entry in ref.watch(addressesProvider).entries) {
    if (entry.value.scheme != DilithiumScheme.mlDsa65) continue;
    final keypair = service.keyPairAtPath(mnemonic, entry.value.derivationPath, entry.value.scheme);
    if (hex.encode(keypair.publicKey) == publicKeyHex) return entry.key;
  }
  return null;
});

/// The first account, which the home screen leads with.
final addressProvider = Provider<String?>((ref) => ref.watch(addressesProvider).keys.firstOrNull);

/// The address a derivation path produces, so an account can be checked before
/// it is added. Auto-disposed: a path still being typed is not worth keeping.
final derivedAddressProvider = FutureProvider.autoDispose.family<String, ({String path, DilithiumScheme scheme})>((
  ref,
  key,
) async {
  final mnemonic = ref.watch(walletControllerProvider).mnemonic;
  if (mnemonic == null) throw StateError('Wallet is locked');
  return HdWalletService().keyPairAtPath(mnemonic, key.path, key.scheme).ss58Address;
});

/// Resolves human checkphrases for every address on screen, not just the
/// wallet's own — an approval or a governance call can name several accounts,
/// and each one needs to be verifiable by eye.
final checksumNameProvider = FutureProvider.family<String, String>((ref, address) async {
  return (await HumanReadableChecksumService().getHumanReadableName(address)) ?? '';
});

final checkphraseProvider = FutureProvider<String>((ref) async {
  final address = ref.watch(addressProvider);
  if (address == null) return '';
  return ref.watch(checksumNameProvider(address).future);
});
