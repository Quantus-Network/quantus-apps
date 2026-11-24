import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' show SealPolicy;
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';
import 'package:quantus_cold_wallet/services/cold_key_service.dart';

/// [keyLost] is a sealed wallet whose phrase the device destroyed: its accounts are
/// still listed, and only the recovery phrase brings their key back.
enum WalletStatus { initializing, needsSetup, needsMigration, locked, unlocked, keyLost }

/// What the device key entry is behind. [upgradePending] is a plain entry on
/// a device that can now protect it: the next read moves it behind user
/// presence, and that move's prompt gates the read. [legacyPrompt] is a plain
/// entry the previous app version kept behind its own device prompt, which
/// stays in front of it. [none] was accepted on the no-lock warning.
/// [biometryEachUse] and [passcodeEachUse] are a sealed phrase: there is no
/// device key, and every use of the phrase needs a biometric match, or the
/// device passcode on a device that had no biometric enrolled.
enum KeyProtection { userPresence, upgradePending, legacyPrompt, none, biometryEachUse, passcodeEachUse }

/// [WalletState.error] after the user dismissed the device prompt.
const unlockCancelledError = 'cancelled';

@immutable
class WalletState {
  final WalletStatus status;

  /// Held only by a wallet that opens a vault for the session. A sealed
  /// wallet never keeps the phrase.
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

/// The key cannot be used, for the reason [message] gives the user.
class KeyRefused implements Exception {
  final String message;

  const KeyRefused(this.message);

  @override
  String toString() => message;
}

/// Injectable so a test can stand in for the platform biometric prompt.
final coldAuthServiceProvider = Provider<ColdAuthService>((ref) => ColdAuthService());

/// Injectable so a test can stand in for the Rust signer and the sealed store.
final coldKeyServiceProvider = Provider<ColdKeyService>((ref) => ColdKeyService());

/// What a phrase sealed now would be behind, or null on a device without a
/// screen lock. Read again whenever the app returns to the foreground, since
/// the user changes it in the system settings.
final sealPolicyProvider = FutureProvider.autoDispose<SealPolicy?>((ref) async {
  try {
    return await ref.watch(coldKeyServiceProvider).availablePolicy();
  } catch (e, st) {
    debugPrint('The device did not say what it can seal behind: $e\n$st');
    rethrow;
  }
}, retry: (_, _) => null);

/// What every screen asks of the wallet, whichever way the device holds its
/// recovery phrase.
abstract class WalletController extends Notifier<WalletState> {
  ColdAuthService get auth => ref.read(coldAuthServiceProvider);

  @override
  WalletState build() {
    _start();
    return const WalletState(status: WalletStatus.initializing);
  }

  Future<void> _start() async {
    try {
      state = await load();
    } catch (e, st) {
      debugPrint('Wallet init failed reading secure storage: $e\n$st');
      state = WalletState(status: WalletStatus.initializing, error: 'Could not read secure storage.\n$e');
    }
  }

  Future<void> retryInit() async {
    state = const WalletState(status: WalletStatus.initializing);
    await _start();
  }

  /// What secure storage says the wallet is, without a prompt.
  @protected
  Future<WalletState> load();

  /// Whether the phrase is sealed: every use of the key prompts, and nothing
  /// is derived from the phrase without one.
  bool get sealed;

  /// Every account by its address, in the order the accounts were added.
  Map<String, ColdAccount> get addresses;

  Uint8List publicKeyOf(String address);

  /// How many words the recovery phrase has.
  int get phraseWords;

  /// `signature ‖ public key` over a Quantus extrinsic's signable payload, by
  /// the account at [address]. Throws [KeyRefused] when the key cannot be
  /// used and as the key store does when its prompt is dismissed.
  Future<Uint8List> signExtrinsic(String address, Uint8List message, {required int specVersion});

  /// `signature ‖ public key` over a borsh NEAR transaction, as the NEAR
  /// runtime verifies it. Throws as [signExtrinsic] does.
  Future<Uint8List> signNear(String address, List<int> transaction);

  /// The recovery phrase after a fresh confirmation that it is the user
  /// asking, or null when the prompt was dismissed.
  Future<String?> revealPhrase();

  /// Throws unless [phrase] is a recovery phrase that derives [accounts] and
  /// may become this wallet's.
  Future<void> checkPhrase(String phrase, List<ColdAccount> accounts);

  Future<void> createWallet({required String mnemonic, required List<ColdAccount> accounts, required bool protected});

  /// Moves a wallet an earlier app version created to how this one holds the
  /// key. False when what should open the old wallet does not, before
  /// anything is written.
  Future<bool> migrateLegacy(String password, {required bool protected});

  Future<KeyProtection> keyProtection();

  /// Moves a phrase sealed behind the passcode behind the biometrics enrolled
  /// since. Throws as [signExtrinsic] does, and then nothing has moved.
  Future<void> sealBehindBiometrics();

  void lockOnBackground();

  Future<void> wipe();

  /// Stores [accounts] as the wallet's list and publishes it.
  @protected
  Future<void> saveAccounts(List<ColdAccount> accounts);

  /// Adds an account derived from the phrase the wallet already holds.
  Future<void> addAccount(ColdAccount account) => saveAccounts([...state.accounts, account]);

  Future<void> renameAccount(ColdAccount account, String label) {
    _requireHeld(account);
    return saveAccounts([for (final a in state.accounts) a.derivesSameKey(account) ? a.withLabel(label) : a]);
  }

  /// Drops [account] from the wallet. The phrase still derives it, so adding
  /// the same derivation path again brings it back.
  Future<void> removeAccount(ColdAccount account) {
    _requireHeld(account);
    final accounts = state.accounts.where((a) => !a.derivesSameKey(account)).toList();
    if (accounts.isEmpty) throw StateError('The last account cannot be removed');
    return saveAccounts(accounts);
  }

  void _requireHeld(ColdAccount account) {
    if (!state.accounts.any(account.derivesSameKey)) throw StateError('Account ${account.label} is not in this wallet');
  }
}
