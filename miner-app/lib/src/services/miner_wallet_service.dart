import 'dart:io';
import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('MinerWallet');

/// Miner wallet: mnemonic (secure storage) + rewards preimage (file on disk).
///
/// Two setup flows are supported:
/// - Full: mnemonic is stored and the wormhole key pair can be re-derived (enables
///   withdrawals later).
/// - Preimage-only: only the rewards preimage file is written. The node can mine
///   but the user must withdraw via CLI.
class MinerWalletService {
  static final MinerWalletService _instance = MinerWalletService._internal();
  factory MinerWalletService() => _instance;

  static const String _mnemonicKey = 'miner_mnemonic';
  static const String _rewardsPreimageFileName = 'rewards-preimage.txt';
  static const String _legacyRewardsAddressFileName = 'rewards-address.txt';

  final FlutterSecureStorage _secureStorage;
  final HdWalletService _hdWallet = HdWalletService();

  MinerWalletService._internal()
    : _secureStorage = const FlutterSecureStorage(
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );

  Future<File> _preimageFile() async =>
      File('${await BinaryManager.getQuantusHomeDirectoryPath()}/$_rewardsPreimageFileName');
  Future<File> _legacyPreimageFile() async =>
      File('${await BinaryManager.getQuantusHomeDirectoryPath()}/$_legacyRewardsAddressFileName');

  /// Generate a new 24-word mnemonic (256 bits of entropy).
  String generateMnemonic() {
    final random = Random.secure();
    final entropy = List<int>.generate(32, (_) => random.nextInt(256));
    return Mnemonic(entropy, Language.english).sentence;
  }

  bool validateMnemonic(String mnemonic) {
    try {
      Mnemonic.fromSentence(mnemonic.trim(), Language.english);
      return true;
    } catch (e) {
      _log.w('Invalid mnemonic: $e');
      return false;
    }
  }

  /// Save the mnemonic securely and derive + persist the wormhole key pair.
  Future<WormholeKeyPair> saveMnemonic(String mnemonic) async {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final trimmed = mnemonic.trim();
    await _secureStorage.write(key: _mnemonicKey, value: trimmed);
    _log.i('Mnemonic saved securely');

    final keyPair = _hdWallet.deriveMinerRewardsKeyPair(mnemonic: trimmed, index: 0);
    await _saveRewardsPreimage(keyPair.rewardsPreimage);

    _log.i('Wormhole address derived: ${keyPair.address}');
    return keyPair;
  }

  Future<String?> getMnemonic() => _secureStorage.read(key: _mnemonicKey);

  Future<bool> hasMnemonic() async {
    final mnemonic = await getMnemonic();
    return mnemonic != null && mnemonic.isNotEmpty;
  }

  /// Wormhole key pair derived from the stored mnemonic, or null if no mnemonic.
  Future<WormholeKeyPair?> getWormholeKeyPair() async {
    final mnemonic = await getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) return null;
    return _hdWallet.deriveMinerRewardsKeyPair(mnemonic: mnemonic, index: 0);
  }

  /// Hex value for the node's `--rewards-inner-hash` flag. Falls back to the
  /// preimage-only file when no mnemonic is stored.
  Future<String?> getRewardsInnerHash() async {
    final keyPair = await getWormholeKeyPair();
    if (keyPair != null) return keyPair.rewardsPreimageHex;
    final fromFile = await readRewardsPreimageFile();
    if (fromFile == null || fromFile.isEmpty) return null;
    return _hdWallet.preimageSs58ToHex(fromFile);
  }

  /// SS58 wormhole address where rewards are sent.
  Future<String?> getRewardsAddress() async {
    final keyPair = await getWormholeKeyPair();
    if (keyPair != null) return keyPair.address;
    final hexPreimage = await getRewardsInnerHash();
    if (hexPreimage == null) return null;
    return _hdWallet.preimageToAddress(hexPreimage);
  }

  Future<bool> hasRewardsPreimageFile() async {
    try {
      return await (await _preimageFile()).exists();
    } catch (e) {
      _log.e('Error checking rewards preimage file', error: e);
      return false;
    }
  }

  Future<String?> readRewardsPreimageFile() async {
    try {
      final file = await _preimageFile();
      if (!await file.exists()) return null;
      return (await file.readAsString()).trim();
    } catch (e) {
      _log.e('Error reading rewards preimage file', error: e);
      return null;
    }
  }

  Future<void> _saveRewardsPreimage(String preimage) async {
    try {
      final file = await _preimageFile();
      await file.writeAsString(preimage);
      _log.i('Rewards preimage saved to: ${file.path}');

      final legacy = await _legacyPreimageFile();
      if (await legacy.exists()) {
        await legacy.delete();
        _log.i('Deleted legacy rewards address file');
      }
    } catch (e) {
      _log.e('Error saving rewards preimage', error: e);
      rethrow;
    }
  }

  /// Validate a rewards preimage (SS58 base58 shape check).
  bool validatePreimage(String preimage) => _hdWallet.validatePreimage(preimage);

  /// Save just the rewards preimage (no mnemonic). Mining only; withdrawals
  /// require the secret via another tool.
  Future<void> savePreimageOnly(String preimage) async {
    final trimmed = preimage.trim();
    if (!validatePreimage(trimmed)) {
      throw ArgumentError('Invalid preimage format. Expected SS58-encoded address.');
    }
    await _saveRewardsPreimage(trimmed);
    _log.i('Preimage saved (without mnemonic)');
  }

  Future<bool> canWithdraw() => hasMnemonic();

  /// Delete mnemonic + preimage files (logout/reset).
  Future<void> deleteWalletData() async {
    _log.i('Deleting wallet data...');

    try {
      await _secureStorage.delete(key: _mnemonicKey);
      _log.i('Mnemonic deleted from secure storage');
    } catch (e) {
      _log.e('Error deleting mnemonic', error: e);
    }

    for (final getFile in [_preimageFile, _legacyPreimageFile]) {
      try {
        final file = await getFile();
        if (await file.exists()) {
          await file.delete();
          _log.i('Deleted: ${file.path}');
        }
      } catch (e) {
        _log.e('Error deleting wallet file', error: e);
      }
    }
  }

  /// True if either the new preimage file or the legacy address file exists.
  Future<bool> isSetupComplete() async {
    if (await hasRewardsPreimageFile()) return true;
    try {
      return await (await _legacyPreimageFile()).exists();
    } catch (_) {
      return false;
    }
  }
}
