import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

enum WalletStatus { initializing, needsSetup, locked, unlocked }

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
  return HumanReadableChecksumService().getHumanReadableName(address);
});
