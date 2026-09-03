import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

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
        accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy)],
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
/// [FlutterSecureStorage]. Biometric unlock stores the derived key under a
/// separate secure-storage entry, gated by a [local_auth] check at the app
/// layer.
class VaultService {
  static const _vaultKey = 'cold_vault';
  static const _bioKeyKey = 'cold_unlock_key';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  static const _legacyStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static final Argon2id _kdf = Argon2id(memory: 8192, parallelism: 1, iterations: 3, hashLength: 32);
  final AesGcm _aead = AesGcm.with256bits();

  bool _keychainMigrated = false;

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

  Future<bool> hasWallet() async {
    await _ensureKeychainMigrated();
    return (await _storage.read(key: _vaultKey)) != null;
  }

  /// True only when the stored biometric key belongs to the current vault
  /// (matched via the vault salt it was paired with). A key orphaned by a
  /// rotation that died between the vault write and the re-store is deleted
  /// here, so startup never advertises an unlock option that cannot work.
  /// Pre-pairing entries (bare base64) carry no salt and are instead
  /// validated at use in [unlockWithBiometricKey].
  Future<bool> isBiometricEnabled() async {
    final raw = await _storage.read(key: _bioKeyKey);
    if (raw == null) return false;
    final vaultSalt = await _vaultSaltB64();
    if (vaultSalt == null) return false;
    final entry = _decodeBioEntry(raw);
    if (entry.salt == null || entry.salt == vaultSalt) return true;
    debugPrint('Biometric key belongs to a previous vault (interrupted rotation); removing it');
    await _storage.delete(key: _bioKeyKey);
    return false;
  }

  Future<String?> _vaultSaltB64() async {
    final raw = await _storage.read(key: _vaultKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map<String, dynamic>)['salt'] as String;
  }

  ({String? salt, String key}) _decodeBioEntry(String raw) {
    if (!raw.startsWith('{')) return (salt: null, key: raw);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (salt: m['salt'] as String, key: m['key'] as String);
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

  /// Pairs the key with the current vault via its salt, so a key orphaned by
  /// an interrupted rotation is detectable at the next launch.
  Future<void> storeBiometricKey(List<int> keyBytes) async {
    final vaultSalt = await _vaultSaltB64();
    if (vaultSalt == null) throw StateError('No wallet vault found');
    await _storage.write(key: _bioKeyKey, value: jsonEncode({'salt': vaultSalt, 'key': base64Encode(keyBytes)}));
  }

  Future<void> disableBiometric() async => _storage.delete(key: _bioKeyKey);

  Future<UnlockResult> unlockWithBiometricKey() async {
    final raw = await _storage.read(key: _bioKeyKey);
    if (raw == null) throw StateError('Biometric unlock not set up');
    final keyBytes = base64Decode(_decodeBioEntry(raw).key);
    try {
      final contents = VaultContents.decode(await _decrypt(await _readVault(), SecretKey(keyBytes)));
      return UnlockResult(mnemonic: contents.mnemonic, accounts: contents.accounts, keyBytes: keyBytes);
    } on SecretBoxAuthenticationError {
      // The key cannot authenticate this vault, so it belongs to a previous
      // one; drop it so the broken unlock option disappears.
      debugPrint('Biometric key failed to decrypt the vault; removing it');
      await _storage.delete(key: _bioKeyKey);
      rethrow;
    }
  }

  Future<void> wipe() async {
    await _storage.delete(key: _vaultKey);
    await _storage.delete(key: _bioKeyKey);
  }

  Uint8List _randomBytes(int n) {
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
