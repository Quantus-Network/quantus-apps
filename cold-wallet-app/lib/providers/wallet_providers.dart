import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

enum WalletStatus { initializing, needsSetup, locked, unlocked }

/// Outcome of a password rotation. The vault write is the commit point:
/// [changed] and [changedBiometricDisabled] both mean the new password is in
/// effect; the latter means the biometric unlock key could not be re-stored
/// and biometric unlock was turned off.
enum PasswordChangeResult { wrongPassword, changed, changedBiometricDisabled }

@immutable
class WalletState {
  final WalletStatus status;
  final String? mnemonic;
  final List<ColdAccount> accounts;
  final bool biometricEnabled;
  final String? error;

  const WalletState({
    required this.status,
    this.mnemonic,
    this.accounts = const [],
    this.biometricEnabled = false,
    this.error,
  });

  WalletState copyWith({WalletStatus? status, String? mnemonic, List<ColdAccount>? accounts, bool? biometricEnabled}) =>
      WalletState(
        status: status ?? this.status,
        mnemonic: mnemonic ?? this.mnemonic,
        accounts: accounts ?? this.accounts,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      );
}

class WalletController extends Notifier<WalletState> {
  final VaultService _vault = VaultService();
  final ColdAuthService _auth = ColdAuthService();

  List<int>? _keyBytes;

  VaultService get vault => _vault;
  ColdAuthService get auth => _auth;

  @override
  WalletState build() {
    _init();
    return const WalletState(status: WalletStatus.initializing);
  }

  Future<void> _init() async {
    try {
      final hasWallet = await _vault.hasWallet();
      final biometric = await _vault.isBiometricEnabled();
      state = WalletState(
        status: hasWallet ? WalletStatus.locked : WalletStatus.needsSetup,
        biometricEnabled: biometric,
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

  Future<void> createWallet({
    required String mnemonic,
    required String password,
    required bool enableBiometric,
    required List<ColdAccount> accounts,
  }) async {
    await _vault.createVault(mnemonic: mnemonic, password: password, accounts: accounts);
    if (enableBiometric) {
      final result = await _vault.unlockWithPassword(password);
      await _vault.storeBiometricKey(result.keyBytes);
    } else {
      // A biometric key left over from an earlier vault must not survive.
      await _vault.disableBiometric();
    }
    _keyBytes = (await _vault.unlockWithPassword(password)).keyBytes;
    state = WalletState(
      status: WalletStatus.unlocked,
      mnemonic: mnemonic,
      accounts: accounts,
      biometricEnabled: enableBiometric,
    );
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

  Future<bool> unlockWithBiometric() async {
    final authenticated = await _auth.authenticate('Unlock your cold wallet');
    if (!authenticated) return false;
    try {
      final contents = await _vault.unlockWithBiometricKey();
      state = state.copyWith(status: WalletStatus.unlocked, mnemonic: contents.mnemonic, accounts: contents.accounts);
      return true;
    } on SecretBoxAuthenticationError {
      // The vault removed a key that belonged to a previous vault; stop
      // offering biometric unlock and let the user fall back to the password.
      debugPrint('Biometric unlock failed with a stale key; biometric unlock disabled');
      state = state.copyWith(biometricEnabled: false);
      return false;
    } catch (e) {
      debugPrint('Biometric unlock failed: $e');
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
    final biometric = await _vault.isBiometricEnabled();
    await _vault.createVault(mnemonic: result.mnemonic, password: newPassword, accounts: result.accounts);

    // The vault is now under a key the old one cannot open, so anything that
    // rewrites it in this session - adding an account - must use the new key.
    final fresh = await _vault.unlockWithPassword(newPassword);
    _keyBytes = fresh.keyBytes;

    if (!biometric) return PasswordChangeResult.changed;
    try {
      await _vault.storeBiometricKey(fresh.keyBytes);
      return PasswordChangeResult.changed;
    } catch (e, st) {
      debugPrint('Change password: biometric key re-store failed, biometric unlock disabled: $e\n$st');
      try {
        // The stored key still belongs to the old vault and can no longer
        // decrypt anything; leaving it would offer a biometric unlock that
        // always fails.
        await _vault.disableBiometric();
      } catch (e2, st2) {
        debugPrint('Change password: stale biometric key could not be removed: $e2\n$st2');
      }
      state = state.copyWith(biometricEnabled: false);
      return PasswordChangeResult.changedBiometricDisabled;
    }
  }

  /// Adds an account derived from the seed already in the vault.
  Future<void> addAccount(ColdAccount account) async {
    final mnemonic = state.mnemonic;
    final keyBytes = _keyBytes;
    if (mnemonic == null || keyBytes == null) throw StateError('Wallet is locked');

    final accounts = [...state.accounts, account];
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

  Future<void> wipe() async {
    _keyBytes = null;
    await _vault.wipe();
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}

final walletControllerProvider = NotifierProvider<WalletController, WalletState>(WalletController.new);

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
      service.keyPairAtPath(mnemonic, account.derivationPath).ss58Address: account,
  };
});

Keypair? keypairFor(WidgetRef ref, String address) {
  final mnemonic = ref.read(walletControllerProvider).mnemonic;
  final account = ref.read(addressesProvider)[address];
  if (mnemonic == null || account == null) return null;
  return HdWalletService().keyPairAtPath(mnemonic, account.derivationPath);
}

/// The first account, which the home screen leads with.
final addressProvider = Provider<String?>((ref) => ref.watch(addressesProvider).keys.firstOrNull);

/// Resolves human checkphrases for every address on screen, not just the
/// wallet's own — an approval or a governance call can name several accounts,
/// and each one needs to be verifiable by eye.
final addressCheckphraseProvider = FutureProvider.family<String, String>((ref, address) async {
  return (await HumanReadableChecksumService().getHumanReadableName(address)) ?? '';
});

final checkphraseProvider = FutureProvider<String>((ref) async {
  final address = ref.watch(addressProvider);
  if (address == null) return '';
  return ref.watch(addressCheckphraseProvider(address).future);
});
