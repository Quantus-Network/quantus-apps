import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

/// The user dismissed the system prompt that releases the device key.
class VaultAccessCancelled implements Exception {
  final PlatformException cause;

  const VaultAccessCancelled(this.cause);

  @override
  String toString() => 'Vault access cancelled: ${cause.message}';
}

/// Which plain key entry a vault has: none; a legacy one, written by the app
/// version that kept it behind its own device prompt and a password; or an
/// accepted one, written on this version once the no-lock warning was taken.
enum PlainKeyKind { none, legacy, accepted }

/// Decrypted result of a successful unlock: the vault contents plus the derived
/// key bytes (so the caller can optionally persist them for biometric unlock).
class UnlockResult {
  final String mnemonic;
  final List<ColdAccount> accounts;
  final List<int> keyBytes;
  const UnlockResult({required this.mnemonic, required this.accounts, required this.keyBytes});
}

/// The vault plaintext. A v1 vault stored the bare mnemonic, so plaintext that
/// is not JSON is read as a single account at index 0.
class VaultContents {
  final String mnemonic;
  final List<ColdAccount> accounts;

  const VaultContents({required this.mnemonic, required this.accounts});

  String encode() => jsonEncode({
    'mnemonic': mnemonic,
    'accounts': [for (final a in accounts) a.toJson()],
  });

  factory VaultContents.decode(String plaintext) {
    if (!plaintext.startsWith('{')) {
      return VaultContents(
        mnemonic: plaintext,
        accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa87)],
      );
    }
    final m = jsonDecode(plaintext) as Map<String, dynamic>;
    return VaultContents(
      mnemonic: m['mnemonic'] as String,
      accounts: [for (final a in m['accounts'] as List) ColdAccount.fromJson(a as Map<String, dynamic>)],
    );
  }
}

/// Encrypts the wallet mnemonic with a password-derived key (Argon2id +
/// AES-GCM) and stores the ciphertext in the platform secure element via
/// [FlutterSecureStorage]. The derived key is kept in a second entry so the
/// vault opens without the password: behind OS-enforced user presence (Face
/// ID, fingerprint or passcode) on a device with a lock, in a plain entry on a
/// device without one.
class VaultService {
  static const _vaultKey = 'cold_vault';
  static const _backupKey = 'cold_vault_backup';
  static const _bioKeyKey = 'cold_unlock_key';
  static const _protectedBioKeyKey = 'cold_unlock_key_protected';
  static const _iosUserCanceled = -128;
  static final _androidCancelCodes = RegExp(r'error \[(5|10|13)\]');

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  static const _legacyStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// iOS prompts on every read of the entry. Android prompts once per process
  /// when the store is first touched, whatever the operation, and serves the
  /// rest of that process silently.
  static const _protectedStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: 'quantus_cold_key',
      accessibility: KeychainAccessibility.unlocked_this_device,
      accessControlFlags: [AccessControlFlag.userPresence],
    ),
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'quantus_cold_key',
      enforceBiometrics: true,
      resetOnError: false,
      biometricPromptTitle: 'Unlock your cold wallet',
      biometricPromptSubtitle: 'Confirm it is you to use your signing key',
    ),
  );

  static final Argon2id _kdf = Argon2id(memory: 8192, parallelism: 1, iterations: 3, hashLength: 32);
  final AesGcm _aead = AesGcm.with256bits();

  bool _keychainMigrated = false;
  int _protectedOps = 0;

  /// True while the protected store may be showing its system prompt, which
  /// sends the app through inactive (iOS) or paused (Android) and back.
  bool get promptInProgress => _protectedOps > 0;

  bool _protectedOpened = false;

  /// Whether this process has opened the protected store. Android prompts
  /// once at that point and serves the rest of the process silently.
  bool get protectedStoreOpened => _protectedOpened;

  /// The internal vault password: never shown, never stored, used once to call
  /// the password APIs before the derived key is kept in the device key entry.
  static String randomSecret() => base64Encode(_randomBytes(32));

  Future<void> _ensureKeychainMigrated() async {
    if (_keychainMigrated) return;
    _keychainMigrated = true;
    for (final key in [_vaultKey, _bioKeyKey]) {
      final value = await _legacyStorage.read(key: key);
      if (value != null) {
        await _legacyStorage.delete(key: key);
        await _storage.write(key: key, value: value);
      }
    }
  }

  Future<T> _guarded<T>(Future<T> Function() op) async {
    _protectedOps++;
    try {
      final result = await op();
      _protectedOpened = true;
      return result;
    } on PlatformException catch (e) {
      if (e.details == _iosUserCanceled || _androidCancelCodes.hasMatch(e.message ?? '')) {
        throw VaultAccessCancelled(e);
      }
      debugPrint('Protected key store failed: ${e.code} ${e.message}');
      rethrow;
    } finally {
      _protectedOps--;
    }
  }

  Future<bool> hasWallet() async {
    await _ensureKeychainMigrated();
    return (await _storage.read(key: _vaultKey)) != null;
  }

  /// The plain key entry, when it belongs to the current vault (matched via
  /// the vault salt it was paired with). A key orphaned by a rotation that
  /// died between the vault write and the re-store is deleted here, so startup
  /// never advertises an unlock option that cannot work. Pre-pairing entries
  /// (bare base64) carry no salt and are instead validated at use in
  /// [unlockWithBiometricKey]. Never prompts.
  Future<PlainKeyKind> plainKeyKind() async {
    final raw = await _storage.read(key: _bioKeyKey);
    if (raw == null) return PlainKeyKind.none;
    final vaultSalt = await _vaultSaltB64();
    if (vaultSalt == null) return PlainKeyKind.none;
    final entry = _decodeBioEntry(raw);
    if (entry.salt != null && entry.salt != vaultSalt) {
      debugPrint('Biometric key belongs to a previous vault (interrupted rotation); removing it');
      await _storage.delete(key: _bioKeyKey);
      return PlainKeyKind.none;
    }
    return entry.accepted ? PlainKeyKind.accepted : PlainKeyKind.legacy;
  }

  Future<bool> hasPlainKey() async => await plainKeyKind() != PlainKeyKind.none;

  /// Whether the protected entry exists, by attributes only: iOS does not
  /// prompt for that. Its salt pairing is checked at use, since reading the
  /// value is what the OS gates.
  Future<bool> hasProtectedKey() => _guarded(() => _protectedStorage.containsKey(key: _protectedBioKeyKey));

  /// A device key entry exists in either store.
  Future<bool> isBiometricEnabled() async => await hasPlainKey() || await hasProtectedKey();

  Future<String?> _vaultSaltB64() async {
    final raw = await _storage.read(key: _vaultKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['salt'] as String;
  }

  ({String? salt, String key, bool accepted}) _decodeBioEntry(String raw) {
    if (!raw.startsWith('{')) return (salt: null, key: raw, accepted: false);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (salt: m['salt'] as String, key: m['key'] as String, accepted: m['accepted'] == true);
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  /// Writes only the vault entry. A biometric key stored for a previous vault
  /// stays valid for that vault until the write lands, so callers own keeping
  /// the biometric entry consistent with the vault they committed.
  Future<void> createVault({
    required String mnemonic,
    required String password,
    required List<ColdAccount> accounts,
  }) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final box = await _aead.encrypt(
      utf8.encode(VaultContents(mnemonic: mnemonic, accounts: accounts).encode()),
      secretKey: key,
    );
    final blob = jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
    await _storage.write(key: _vaultKey, value: blob);
  }

  /// Re-encrypts the vault with the key an unlock already derived, so the
  /// account list can change without asking for the password again. The salt is
  /// preserved, which keeps any paired biometric key valid.
  Future<void> replaceContents({required List<int> keyBytes, required VaultContents contents}) async {
    final existing = await _readVault();
    final box = await _aead.encrypt(utf8.encode(contents.encode()), secretKey: SecretKey(keyBytes));
    await _storage.write(
      key: _vaultKey,
      value: jsonEncode({
        'v': 1,
        'salt': base64Encode(existing.salt),
        'nonce': base64Encode(box.nonce),
        'ct': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  Future<_Vault> _readVault() async {
    final raw = await _storage.read(key: _vaultKey);
    if (raw == null) throw StateError('No wallet vault found');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return _Vault(
      salt: base64Decode(m['salt'] as String),
      nonce: base64Decode(m['nonce'] as String),
      cipherText: base64Decode(m['ct'] as String),
      mac: base64Decode(m['mac'] as String),
    );
  }

  Future<String> _decrypt(_Vault v, SecretKey key) async {
    final clear = await _aead.decrypt(
      SecretBox(v.cipherText, nonce: v.nonce, mac: Mac(v.mac)),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  /// Throws [SecretBoxAuthenticationError] if the password is wrong.
  Future<UnlockResult> unlockWithPassword(String password) async {
    final v = await _readVault();
    final key = await _deriveKey(password, v.salt);
    final contents = VaultContents.decode(await _decrypt(v, key));
    return UnlockResult(mnemonic: contents.mnemonic, accounts: contents.accounts, keyBytes: await key.extractBytes());
  }

  /// Keeps the derived key in the store [protected] selects, paired with the
  /// current vault via its salt so a key orphaned by an interrupted rotation is
  /// detectable at the next launch. The entry is read back and compared: on
  /// iOS that read is the user-presence confirmation, on Android the write
  /// already prompted. A cancelled read-back removes what was written and
  /// throws [VaultAccessCancelled].
  ///
  /// The protected branch removes the plain entry. The plain branch leaves a
  /// protected entry alone: it is only taken on a device without a lock, where
  /// the protected store cannot be opened, and reads try the plain entry first.
  /// It marks the entry as accepted on the no-lock warning, which tells it
  /// from one the previous app version wrote ([PlainKeyKind]).
  Future<void> storeBiometricKey(List<int> keyBytes, {required bool protected}) async {
    final vaultSalt = await _vaultSaltB64();
    if (vaultSalt == null) throw StateError('No wallet vault found');
    final value = jsonEncode({'salt': vaultSalt, 'key': base64Encode(keyBytes), if (!protected) 'accepted': true});
    if (!protected) {
      await _storage.write(key: _bioKeyKey, value: value);
      _verifyReadBack(await _storage.read(key: _bioKeyKey), value);
      return;
    }
    await _guarded(() => _protectedStorage.write(key: _protectedBioKeyKey, value: value));
    final String? readBack;
    try {
      readBack = await _guarded(() => _protectedStorage.read(key: _protectedBioKeyKey));
    } on VaultAccessCancelled {
      await _guarded(() => _protectedStorage.delete(key: _protectedBioKeyKey));
      rethrow;
    }
    _verifyReadBack(readBack, value);
    await _storage.delete(key: _bioKeyKey);
  }

  void _verifyReadBack(String? readBack, String written) {
    if (readBack != written) throw StateError('The key store returned a different entry than was written');
  }

  Future<void> deleteKeyEntry({required bool protected}) =>
      protected ? _guarded(() => _protectedStorage.delete(key: _protectedBioKeyKey)) : _storage.delete(key: _bioKeyKey);

  /// Opens the vault with the stored key: the plain entry first (no prompt),
  /// then the protected one.
  Future<UnlockResult> unlockWithBiometricKey() async {
    final plain = await _storage.read(key: _bioKeyKey);
    final raw = plain ?? await _guarded(() => _protectedStorage.read(key: _protectedBioKeyKey));
    if (raw == null) throw StateError('Biometric unlock not set up');
    final keyBytes = base64Decode(_decodeBioEntry(raw).key);
    try {
      final contents = VaultContents.decode(await _decrypt(await _readVault(), SecretKey(keyBytes)));
      return UnlockResult(mnemonic: contents.mnemonic, accounts: contents.accounts, keyBytes: keyBytes);
    } on SecretBoxAuthenticationError {
      // The key cannot authenticate this vault, so it belongs to a previous
      // one; drop it so the broken unlock option disappears.
      debugPrint('Biometric key failed to decrypt the vault; removing it');
      await deleteKeyEntry(protected: plain == null);
      rethrow;
    }
  }

  /// Copies the vault blob aside so a migration can be undone until its new
  /// key entry is verified readable.
  Future<void> backupVaultForMigration() async {
    final raw = await _storage.read(key: _vaultKey);
    if (raw == null) throw StateError('No wallet vault found');
    await _storage.write(key: _backupKey, value: raw);
  }

  /// Puts a backup back over the vault and removes it. Returns whether one
  /// was present.
  Future<bool> restoreVaultBackupIfPresent() async {
    final raw = await _storage.read(key: _backupKey);
    if (raw == null) return false;
    await _storage.write(key: _vaultKey, value: raw);
    await _storage.delete(key: _backupKey);
    return true;
  }

  Future<void> deleteVaultBackup() => _storage.delete(key: _backupKey);

  /// Removes everything. The protected entry goes first so a cancelled prompt
  /// leaves the wallet intact. A protected store the OS can no longer open
  /// (Android after the device lock was removed or the key invalidated) is
  /// logged and skipped: that entry can unlock nothing once the vault is gone,
  /// and this wipe is the user's only way out.
  Future<void> wipe() async {
    await _deleteProtectedEntry(keepOnCancel: true);
    await _deletePlainEntries();
  }

  /// Removes a vault whose creation did not finish. Nothing can open it, so
  /// it goes first; the protected entry follows as far as the store allows,
  /// since its prompt may be cancelled too, and an entry left behind is
  /// overwritten by the next creation.
  Future<void> discardIncompleteVault() async {
    await _deletePlainEntries();
    await _deleteProtectedEntry(keepOnCancel: false);
  }

  Future<void> _deleteProtectedEntry({required bool keepOnCancel}) async {
    try {
      await _guarded(() => _protectedStorage.delete(key: _protectedBioKeyKey));
    } on VaultAccessCancelled {
      if (keepOnCancel) rethrow;
      debugPrint('Protected key entry deletion cancelled; the next creation overwrites it');
    } catch (e, st) {
      debugPrint('Protected key entry could not be deleted during wipe: $e\n$st');
    }
  }

  Future<void> _deletePlainEntries() async {
    await _storage.delete(key: _vaultKey);
    await _storage.delete(key: _backupKey);
    await _storage.delete(key: _bioKeyKey);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}

class _Vault {
  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
  _Vault({required this.salt, required this.nonce, required this.cipherText, required this.mac});
}
