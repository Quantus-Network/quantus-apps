import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
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
  final bool biometricEnabled;
  final String? error;

  const WalletState({required this.status, this.mnemonic, this.biometricEnabled = false, this.error});

  WalletState copyWith({WalletStatus? status, String? mnemonic, bool? biometricEnabled}) => WalletState(
    status: status ?? this.status,
    mnemonic: mnemonic ?? this.mnemonic,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
  );
}

class WalletController extends Notifier<WalletState> {
  final VaultService _vault = VaultService();
  final ColdAuthService _auth = ColdAuthService();

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

  Future<void> createWallet({required String mnemonic, required String password, required bool enableBiometric}) async {
    await _vault.createVault(mnemonic: mnemonic, password: password);
    if (enableBiometric) {
      final result = await _vault.unlockWithPassword(password);
      await _vault.storeBiometricKey(result.keyBytes);
    }
    state = WalletState(status: WalletStatus.unlocked, mnemonic: mnemonic, biometricEnabled: enableBiometric);
  }

  Future<bool> unlockWithPassword(String password) async {
    try {
      final result = await _vault.unlockWithPassword(password);
      state = state.copyWith(status: WalletStatus.unlocked, mnemonic: result.mnemonic);
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
      final mnemonic = await _vault.unlockWithBiometricKey();
      state = state.copyWith(status: WalletStatus.unlocked, mnemonic: mnemonic);
      return true;
    } catch (e) {
      debugPrint('Biometric unlock failed: $e');
      return false;
    }
  }

  /// Verifies [currentPassword] against the vault, then re-encrypts the
  /// mnemonic under [newPassword]. The vault write is the commit point: any
  /// failure before it rethrows with the old password still valid, while a
  /// biometric re-store failure after it keeps the committed change and
  /// reports biometric unlock as disabled.
  Future<PasswordChangeResult> changePassword({required String currentPassword, required String newPassword}) async {
    final UnlockResult result;
    try {
      result = await _vault.unlockWithPassword(currentPassword);
    } on SecretBoxAuthenticationError {
      debugPrint('Change password: current password rejected');
      return PasswordChangeResult.wrongPassword;
    }
    final biometric = await _vault.isBiometricEnabled();
    try {
      await _vault.createVault(mnemonic: result.mnemonic, password: newPassword);
    } catch (e) {
      // createVault drops the biometric key before writing, so a failed write
      // keeps the old password valid but may have lost biometric unlock.
      if (biometric) state = state.copyWith(biometricEnabled: false);
      rethrow;
    }
    if (!biometric) return PasswordChangeResult.changed;
    try {
      final fresh = await _vault.unlockWithPassword(newPassword);
      await _vault.storeBiometricKey(fresh.keyBytes);
      return PasswordChangeResult.changed;
    } catch (e, st) {
      debugPrint('Change password: biometric key re-store failed, biometric unlock disabled: $e\n$st');
      state = state.copyWith(biometricEnabled: false);
      return PasswordChangeResult.changedBiometricDisabled;
    }
  }

  void lock() {
    if (state.status != WalletStatus.unlocked) return;
    state = WalletState(status: WalletStatus.locked, biometricEnabled: state.biometricEnabled);
  }

  Future<void> wipe() async {
    await _vault.wipe();
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}

final walletControllerProvider = NotifierProvider<WalletController, WalletState>(WalletController.new);

/// The cold wallet manages a single account: HD index 0, matching the default
/// account the hot wallet derives, so the address shown here is the one a hot
/// wallet imports as a keystone account.
final keypairProvider = Provider<Keypair?>((ref) {
  final mnemonic = ref.watch(walletControllerProvider).mnemonic;
  if (mnemonic == null) return null;
  return HdWalletService().keyPairAtIndex(mnemonic, 0);
});

final addressProvider = Provider<String?>((ref) => ref.watch(keypairProvider)?.ss58Address);

final checkphraseProvider = FutureProvider<String>((ref) async {
  final address = ref.watch(addressProvider);
  if (address == null) return '';
  final name = await HumanReadableChecksumService().getHumanReadableName(address);
  return name ?? '';
});
