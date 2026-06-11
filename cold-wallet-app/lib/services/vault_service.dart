import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Decrypted result of a successful unlock: the mnemonic plus the derived key
/// bytes (so the caller can optionally persist them for biometric unlock).
class UnlockResult {
  final String mnemonic;
  final List<int> keyBytes;
  const UnlockResult({required this.mnemonic, required this.keyBytes});
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
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // Argon2id parameters. Tunable: a cold wallet favors strength, but the
  // pure-Dart KDF runs on-device so we keep memory modest to bound unlock time.
  static final Argon2id _kdf = Argon2id(memory: 8192, parallelism: 1, iterations: 3, hashLength: 32);
  final AesGcm _aead = AesGcm.with256bits();

  Future<bool> hasWallet() async => (await _storage.read(key: _vaultKey)) != null;

  Future<bool> isBiometricEnabled() async => (await _storage.read(key: _bioKeyKey)) != null;

  Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<void> createVault({required String mnemonic, required String password}) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final box = await _aead.encrypt(utf8.encode(mnemonic), secretKey: key);
    final blob = jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
    await _storage.write(key: _vaultKey, value: blob);
    // (Re)creating a wallet invalidates any previously stored biometric key.
    await _storage.delete(key: _bioKeyKey);
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
    final mnemonic = await _decrypt(v, key);
    return UnlockResult(mnemonic: mnemonic, keyBytes: await key.extractBytes());
  }

  Future<void> storeBiometricKey(List<int> keyBytes) async =>
      _storage.write(key: _bioKeyKey, value: base64Encode(keyBytes));

  Future<void> disableBiometric() async => _storage.delete(key: _bioKeyKey);

  Future<String> unlockWithBiometricKey() async {
    final raw = await _storage.read(key: _bioKeyKey);
    if (raw == null) throw StateError('Biometric unlock not set up');
    return _decrypt(await _readVault(), SecretKey(base64Decode(raw)));
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
