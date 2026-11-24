import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/models/held_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_controller.dart';
import 'package:quantus_cold_wallet/services/cold_key_service.dart';
import 'package:quantus_cold_wallet/services/held_account_store.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/ui/seal_wording.dart';

/// The wallet on a device that seals the recovery phrase: behind its
/// biometrics, or behind its passcode while it has none enrolled. Nothing is
/// unlocked for a session: the app opens without a prompt on the public half
/// of its accounts, and each signature takes the phrase out of the sealed
/// store inside Rust, behind its own prompt, and wipes it.
class SealedWalletController extends WalletController {
  static const _signPrompt = 'Sign this transaction';
  static const _revealPrompt = 'Show your recovery phrase';
  static const _confirmPrompt = 'Confirm your new signing key';
  static const _addAccountPrompt = 'Add an account';
  static const _movePrompt = 'Move your signing key';
  static const _otherWalletMessage = 'This recovery phrase belongs to a different wallet.';

  final HeldAccountStore _store = HeldAccountStore();

  /// The wallet an earlier app version left, read once to move it here.
  final VaultService _vault = VaultService();

  HeldAccounts? _held;

  ColdKeyService get _keys => ref.read(coldKeyServiceProvider);

  @override
  bool get sealed => true;

  @override
  Future<WalletState> load() async {
    final held = await _store.read();
    final hasPhrase = await _use(_keys.sealedPolicy) != null;
    if (held != null) {
      _held = held;
      if (hasPhrase) await _discardLegacyVault();
      return WalletState(status: hasPhrase ? WalletStatus.unlocked : WalletStatus.keyLost, accounts: held.coldAccounts);
    }
    if (hasPhrase) {
      debugPrint('Removing a sealed phrase whose creation never finished');
      await _use(_keys.delete);
    }
    if (!await _vault.hasWallet()) return const WalletState(status: WalletStatus.needsSetup);
    final canProtect = await auth.deviceCanProtect();
    final interrupted = await _vault.undoInterruptedMigration(canProtect: canProtect);
    return WalletState(
      status: WalletStatus.needsMigration,
      biometricEnabled: !interrupted && await _legacyHasDeviceKey(canProtect),
    );
  }

  /// Where even looking into the protected store prompts, a device that can
  /// protect is taken to hold the old vault's key there, and the migration
  /// finds out.
  Future<bool> _legacyHasDeviceKey(bool canProtect) async =>
      await _vault.hasPlainKey() ||
      (auth.storeAuthenticatesOncePerProcess ? canProtect : await _vault.hasProtectedKey());

  /// Runs one call into the key service and turns what it refused into what
  /// the screens show.
  Future<T> _use<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on SealedKeyError catch (e) {
      debugPrint('Sealed key refused: ${e.failure.name}, ${e.detail}');
      switch (e.failure) {
        case SealedKeyFailure.cancelled:
          throw VaultAccessCancelled(PlatformException(code: e.failure.name, message: e.detail));
        case SealedKeyFailure.notRecognised:
          throw KeyRefused(notRecognisedMessage);
        case SealedKeyFailure.missing:
          if (_held != null) state = state.copyWith(status: WalletStatus.keyLost);
          throw KeyRefused(
            'This $deviceName no longer holds the signing key. Go back and restore it from your recovery phrase.',
          );
        case SealedKeyFailure.unavailable:
          throw KeyRefused(lockRequiredMessage);
        case SealedKeyFailure.wrongAccount || SealedKeyFailure.invalid || SealedKeyFailure.platform:
          throw StateError('Signing key ${e.failure.name}: ${e.detail}');
      }
    }
  }

  HeldAccount _holding(String address) =>
      _held?.accounts.where((held) => held.address == address).firstOrNull ??
      (throw StateError('Account $address is not in this wallet'));

  static HeldAccount _hold(ColdAccount account, AccountPublicKey key) =>
      HeldAccount(account: account, address: key.address, publicKey: key.publicKey);

  @override
  Map<String, ColdAccount> get addresses => {
    for (final held in _held?.accounts ?? const <HeldAccount>[]) held.address: held.account,
  };

  @override
  Uint8List publicKeyOf(String address) => _holding(address).publicKey;

  @override
  int get phraseWords => (_held ?? (throw StateError('No wallet on this device'))).phraseWords;

  @override
  Future<Uint8List> signExtrinsic(String address, Uint8List message, {required int specVersion}) =>
      _use(() => _keys.signExtrinsic(_holding(address).account, address, message, specVersion, _signPrompt));

  @override
  Future<Uint8List> signNear(String address, List<int> transaction) =>
      _use(() => _keys.signNear(_holding(address).account, address, transaction, _signPrompt));

  @override
  Future<String?> revealPhrase() async {
    try {
      return await _use(() => _keys.reveal(_revealPrompt));
    } on VaultAccessCancelled {
      return null;
    }
  }

  /// The public half of [accounts] under [phrase]. While a lost key is being
  /// restored, only the phrase that derives the same addresses is accepted.
  Future<HeldAccounts> _derive(String phrase, List<ColdAccount> accounts) async {
    final keys = await _use(() => _keys.deriveKeys(phrase, accounts));
    final derived = HeldAccounts(
      phraseWords: RegExp(r'\S+').allMatches(phrase).length,
      accounts: [for (final (i, account) in accounts.indexed) _hold(account, keys[i])],
    );
    final lost = _held;
    if (lost != null && !listEquals(lost.addresses, derived.addresses)) throw const KeyRefused(_otherWalletMessage);
    return derived;
  }

  @override
  Future<void> checkPhrase(String phrase, List<ColdAccount> accounts) => _derive(phrase, accounts);

  /// Seals [phrase] behind the strongest policy the device enforces and
  /// proves with one prompted read that the device releases it and that it
  /// derives the key expected. Anything short of that removes the phrase again
  /// and rethrows, so a wallet whose key cannot be used never survives its
  /// creation.
  Future<void> _seal(String phrase, List<ColdAccount> accounts) async {
    final held = await _derive(phrase, accounts);
    final policy = await _use(_keys.availablePolicy) ?? (throw KeyRefused(lockRequiredMessage));
    await _use(() => _keys.seal(phrase, policy));
    try {
      final released = await _use(() => _keys.sealedKeys([accounts.first], _confirmPrompt));
      if (released.single.address != held.accounts.first.address) {
        throw StateError('The sealed phrase derives another key than the phrase entered');
      }
    } catch (e, st) {
      debugPrint('The sealed phrase was not confirmed, removing it: $e\n$st');
      await _use(_keys.delete);
      rethrow;
    }
    await _publish(held);
  }

  Future<void> _publish(HeldAccounts held) async {
    await _store.write(held);
    _held = held;
    state = WalletState(status: WalletStatus.unlocked, accounts: held.coldAccounts);
  }

  @override
  Future<void> createWallet({required String mnemonic, required List<ColdAccount> accounts, required bool protected}) =>
      _seal(mnemonic, accounts);

  /// Opens the old vault with its device key, or with [password] when it has
  /// none, seals its phrase and only then removes the vault. A device key that
  /// is missing or no longer opens the vault leaves the password as the way in.
  @override
  Future<bool> migrateLegacy(String password, {required bool protected}) async {
    final withDeviceKey = state.biometricEnabled;
    final UnlockResult legacy;
    try {
      legacy = withDeviceKey ? await _vault.unlockWithBiometricKey() : await _vault.unlockWithPassword(password);
    } catch (e) {
      final noDeviceKey = withDeviceKey && e is StateError;
      if (e is! SecretBoxAuthenticationError && !noDeviceKey) rethrow;
      debugPrint('Migration: the old vault did not open with ${withDeviceKey ? 'its device key' : 'the password'}: $e');
      if (withDeviceKey) state = state.copyWith(biometricEnabled: false);
      return false;
    }
    await _seal(legacy.mnemonic, legacy.accounts);
    await _discardLegacyVault();
    return true;
  }

  /// The vault goes first; the key entry that opened it follows as far as its
  /// store allows, and unlocks nothing once the vault is gone.
  Future<void> _discardLegacyVault() async {
    if (await _vault.hasWallet()) await _vault.discardVault();
  }

  @override
  Future<KeyProtection> keyProtection() async => switch (await _use(_keys.sealedPolicy)) {
    SealPolicy.biometry => KeyProtection.biometryEachUse,
    SealPolicy.devicePasscode => KeyProtection.passcodeEachUse,
    null => throw StateError('No sealed phrase on this device'),
  };

  @override
  Future<void> sealBehindBiometrics() => _use(() => _keys.reseal(SealPolicy.biometry, _movePrompt));

  /// Nothing is held between uses, so there is nothing to lock.
  @override
  void lockOnBackground() {}

  /// Adding an account derives its public key, which is one prompt;
  /// renaming and removing touch only the public list.
  @override
  Future<void> saveAccounts(List<ColdAccount> accounts) async {
    final held = _held ?? (throw StateError('No wallet on this device'));
    HeldAccount? holding(ColdAccount account) =>
        held.accounts.where((h) => h.account.derivesSameKey(account)).firstOrNull;
    final added = accounts.where((account) => holding(account) == null).toList();
    final keys = added.isEmpty
        ? const <AccountPublicKey>[]
        : await _use(() => _keys.sealedKeys(added, _addAccountPrompt));
    await _publish(
      held.withAccounts([
        for (final account in accounts)
          holding(account)?.withAccount(account) ?? _hold(account, keys[added.indexOf(account)]),
      ]),
    );
  }

  @override
  Future<void> wipe() async {
    await _use(_keys.delete);
    await _store.delete();
    await _discardLegacyVault();
    _held = null;
    state = const WalletState(status: WalletStatus.needsSetup);
  }
}
