import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/src/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user dismissed the system prompt that releases the seed.
class SeedAccessCancelled implements Exception {
  final PlatformException cause;

  const SeedAccessCancelled(this.cause);

  @override
  String toString() => 'Seed access cancelled: ${cause.message}';
}

typedef SeedMover = Future<void> Function(int walletIndex, String mnemonic);

/// Recovery phrases at rest.
///
/// The protected store binds each phrase to user presence: the Secure Enclave
/// (iOS) or StrongBox/TEE (Android) releases the item key only after Face ID,
/// Touch ID, a fingerprint or the device passcode, so a Keychain or Keystore
/// dump by a sandbox-escaped process yields nothing. Devices without a lock
/// keep the plain store; the wallet never forces a passcode.
///
/// iOS prompts on every read. Android opens the store with one prompt per
/// process and serves later reads, writes and deletes in that process
/// silently; that is how the flutter_secure_storage plugin unwraps its key.
///
/// An app-level cryptographic password would wrap the seed here: derive a key
/// from it (Argon2id, as the cold wallet's VaultService does), encrypt the
/// mnemonic in [store] and decrypt it in [read]. Nothing outside this class
/// needs to change.
class SeedVault {
  static const _recordPrefix = 'seed_store_';
  static const _protected = 'protected';
  static const _legacyMigratedKey = 'keychain_migrated_to_this_device';
  static const _androidMinSdk = 28;
  static const _iosUserCanceled = -128;
  static final _androidCancelCodes = RegExp(r'error \[(5|10|13)\]');

  static const _legacyStore = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));
  static const _plainStore = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _protectedStore = FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: 'quantus_seed',
      accessibility: KeychainAccessibility.unlocked_this_device,
      accessControlFlags: [AccessControlFlag.userPresence],
    ),
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'quantus_seed',
      resetOnError: false,
      biometricPromptTitle: 'Unlock your wallet',
      biometricPromptSubtitle: 'Confirm it is you to use your recovery phrase',
    ),
  );

  final SharedPreferences _prefs;
  final Future<bool> Function() _canProtect;
  final Map<int, Future<String?>> _reads = {};
  bool _legacyMigrated = false;
  int _protectedOps = 0;

  /// True while the protected store may be showing its system prompt. The
  /// prompt sends the app through inactive and back, which must not count as
  /// a real backgrounding.
  bool get promptInProgress => _protectedOps > 0;

  SeedVault(this._prefs, {Future<bool> Function()? canProtect}) : _canProtect = canProtect ?? deviceCanProtect;

  /// A lock screen is what the enclave verifies. Below Android 9 the Keystore
  /// cannot show the prompt that unlocks a user-bound key.
  static Future<bool> deviceCanProtect() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    if (Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt < _androidMinSdk) return false;
    return LocalAuthentication().isDeviceSupported();
  }

  static String plainKey(int walletIndex) => walletIndex == 0 ? 'mnemonic' : 'mnemonic_$walletIndex';

  static String _protectedKey(int walletIndex) => 'seed_$walletIndex';

  String _recordKey(int walletIndex) => '$_recordPrefix$walletIndex';

  bool _isProtected(int walletIndex) => _prefs.getString(_recordKey(walletIndex)) == _protected;

  Iterable<int> _protectedWalletIndexes() => _prefs
      .getKeys()
      .where((k) => k.startsWith(_recordPrefix) && _prefs.getString(k) == _protected)
      .map((k) => int.parse(k.substring(_recordPrefix.length)));

  Future<void> store(String mnemonic, int walletIndex) async {
    await _ensureLegacyMigrated();
    if (await _canProtect()) {
      await _guarded(() => _protectedStore.write(key: _protectedKey(walletIndex), value: mnemonic));
      await _prefs.setString(_recordKey(walletIndex), _protected);
      await _plainStore.delete(key: plainKey(walletIndex));
    } else {
      await _plainStore.write(key: plainKey(walletIndex), value: mnemonic);
      await _prefs.remove(_recordKey(walletIndex));
    }
  }

  /// Concurrent readers of one wallet share a single store read, and so a
  /// single prompt.
  Future<String?> read(int walletIndex) => _reads[walletIndex] ??= _readOnce(walletIndex).whenComplete(() {
    _reads.remove(walletIndex);
  });

  Future<String?> _readOnce(int walletIndex) async {
    if (_isProtected(walletIndex)) return _guarded(() => _protectedStore.read(key: _protectedKey(walletIndex)));
    await _ensureLegacyMigrated();
    return _plainStore.read(key: plainKey(walletIndex));
  }

  /// Whether a phrase is stored, without a prompt. Android cannot open the
  /// protected store silently, so there the record is trusted.
  Future<bool> exists(int walletIndex) async {
    if (_isProtected(walletIndex)) {
      return Platform.isAndroid || await _protectedStore.containsKey(key: _protectedKey(walletIndex));
    }
    await _ensureLegacyMigrated();
    return _plainStore.containsKey(key: plainKey(walletIndex));
  }

  Future<void> delete(int walletIndex) async {
    if (_isProtected(walletIndex)) {
      await _guarded(() => _protectedStore.delete(key: _protectedKey(walletIndex)));
      await _prefs.remove(_recordKey(walletIndex));
    }
    await _plainStore.delete(key: plainKey(walletIndex));
  }

  Future<void> deleteAll() async {
    for (final walletIndex in _protectedWalletIndexes().toList()) {
      await delete(walletIndex);
    }
    await _plainStore.deleteAll();
  }

  /// Moves every plain phrase of [walletIndexes] into the protected store once
  /// the device can guard it. [beforeMove] runs while the phrase is still
  /// readable without a prompt. A plain copy left behind by an interrupted
  /// move is removed on the next call.
  Future<void> protectStoredSeeds(Iterable<int> walletIndexes, {required SeedMover beforeMove}) async {
    if (!await _canProtect()) return;
    await _ensureLegacyMigrated();
    for (final walletIndex in walletIndexes) {
      if (_isProtected(walletIndex)) {
        await _plainStore.delete(key: plainKey(walletIndex));
        continue;
      }
      final mnemonic = await _plainStore.read(key: plainKey(walletIndex));
      if (mnemonic == null) continue;
      await beforeMove(walletIndex, mnemonic);
      await store(mnemonic, walletIndex);
      quantusPrint('Wallet $walletIndex seed moved to the protected store');
    }
  }

  Future<T> _guarded<T>(Future<T> Function() op) async {
    _protectedOps++;
    try {
      return await op();
    } on PlatformException catch (e) {
      if (e.details == _iosUserCanceled || _androidCancelCodes.hasMatch(e.message ?? '')) {
        throw SeedAccessCancelled(e);
      }
      quantusPrint('Protected seed store failed: ${e.code} ${e.message}');
      rethrow;
    } finally {
      _protectedOps--;
    }
  }

  /// Phrases written before the store pinned `unlocked_this_device` sit under
  /// the plugin defaults; move them once.
  Future<void> _ensureLegacyMigrated() async {
    if (_legacyMigrated) return;
    _legacyMigrated = true;
    if (_prefs.getBool(_legacyMigratedKey) == true) return;
    try {
      for (int i = 0; i < 10; i++) {
        final value = await _legacyStore.read(key: plainKey(i));
        if (value == null) continue;
        await _legacyStore.delete(key: plainKey(i));
        await _plainStore.write(key: plainKey(i), value: value);
      }
    } catch (e) {
      quantusPrint('Legacy keychain migration failed: $e');
    }
    await _prefs.setBool(_legacyMigratedKey, true);
  }
}
