import 'dart:io';
import 'dart:math';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('MinerWallet');

/// Service for managing the miner's wallet (mnemonic and wormhole key pair).
///
/// The miner uses a wormhole address to receive rewards. This address is derived
/// from a mnemonic using a specific HD path for miner rewards.
///
/// The mnemonic is stored securely using flutter_secure_storage, while the
/// rewards preimage (needed by the node) is stored in a file.
///
/// This is a singleton - use `MinerWalletService()` to get the instance.
class MinerWalletService {
  // Singleton
  static final MinerWalletService _instance = MinerWalletService._internal();
  factory MinerWalletService() => _instance;

  static const String _mnemonicKey = 'miner_mnemonic';
  static const String _rewardsPreimageFileName = 'rewards-preimage.txt';
  // Legacy file for backward compatibility
  static const String _legacyRewardsAddressFileName = 'rewards-address.txt';

  final FlutterSecureStorage _secureStorage;

  MinerWalletService._internal()
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );

  /// Generate a new 24-word mnemonic.
  String generateMnemonic() {
    // Generate 256 bits of entropy for a 24-word mnemonic
    final random = Random.secure();
    final entropy = List<int>.generate(32, (_) => random.nextInt(256));
    final mnemonic = Mnemonic(entropy, Language.english);
    return mnemonic.sentence;
  }

  /// Validate a mnemonic phrase.
  bool validateMnemonic(String mnemonic) {
    try {
      Mnemonic.fromSentence(mnemonic.trim(), Language.english);
      return true;
    } catch (e) {
      _log.w('Invalid mnemonic: $e');
      return false;
    }
  }

  /// Save the mnemonic securely and derive the wormhole key pair.
  ///
  /// Returns the derived [WormholeKeyPair] on success.
  Future<WormholeKeyPair> saveMnemonic(String mnemonic) async {
    // Validate first
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    // Store mnemonic securely
    await _secureStorage.write(key: _mnemonicKey, value: mnemonic.trim());
    _log.i('Mnemonic saved securely');

    // Derive wormhole key pair
    final wormholeService = WormholeService();
    final keyPair = wormholeService.deriveMinerRewardsKeyPair(mnemonic: mnemonic.trim(), index: 0);

    // Save the rewards preimage to file (needed by the node)
    await _saveRewardsPreimage(keyPair.rewardsPreimage);

    _log.i('Wormhole address derived: ${keyPair.address}');
    return keyPair;
  }

  /// Get the stored mnemonic, if any.
  Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: _mnemonicKey);
  }

  /// Check if a mnemonic is stored.
  Future<bool> hasMnemonic() async {
    final mnemonic = await getMnemonic();
    return mnemonic != null && mnemonic.isNotEmpty;
  }

  /// Get the wormhole key pair derived from the stored mnemonic.
  ///
  /// Returns null if no mnemonic is stored.
  Future<WormholeKeyPair?> getWormholeKeyPair() async {
    final mnemonic = await getMnemonic();
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }

    final wormholeService = WormholeService();
    return wormholeService.deriveMinerRewardsKeyPair(mnemonic: mnemonic, index: 0);
  }

  /// Get the rewards inner hash from the stored mnemonic.
  ///
  /// This is the value passed to the node's --rewards-inner-hash flag.
  /// Returns the hex-encoded value with 0x prefix.
  Future<String?> getRewardsInnerHash() async {
    final keyPair = await getWormholeKeyPair();
    return keyPair?.rewardsPreimageHex;
  }

  /// Get the wormhole address where rewards are sent.
  Future<String?> getRewardsAddress() async {
    final keyPair = await getWormholeKeyPair();
    return keyPair?.address;
  }

  /// Check if the rewards preimage file exists.
  Future<bool> hasRewardsPreimageFile() async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final preimageFile = File('$quantusHome/$_rewardsPreimageFileName');
      return await preimageFile.exists();
    } catch (e) {
      _log.e('Error checking rewards preimage file', error: e);
      return false;
    }
  }

  /// Read the rewards preimage from the file.
  Future<String?> readRewardsPreimageFile() async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final preimageFile = File('$quantusHome/$_rewardsPreimageFileName');
      if (await preimageFile.exists()) {
        return (await preimageFile.readAsString()).trim();
      }
      return null;
    } catch (e) {
      _log.e('Error reading rewards preimage file', error: e);
      return null;
    }
  }

  /// Save the rewards preimage to file.
  Future<void> _saveRewardsPreimage(String preimage) async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final preimageFile = File('$quantusHome/$_rewardsPreimageFileName');
      await preimageFile.writeAsString(preimage);
      _log.i('Rewards preimage saved to: ${preimageFile.path}');

      // Also delete legacy rewards-address.txt if it exists
      final legacyFile = File('$quantusHome/$_legacyRewardsAddressFileName');
      if (await legacyFile.exists()) {
        await legacyFile.delete();
        _log.i('Deleted legacy rewards address file');
      }
    } catch (e) {
      _log.e('Error saving rewards preimage', error: e);
      rethrow;
    }
  }

  /// Validate a rewards preimage (SS58 format check).
  ///
  /// The preimage should be a valid SS58 address (the first_hash encoded).
  bool validatePreimage(String preimage) {
    final trimmed = preimage.trim();
    // Basic SS58 validation: starts with valid prefix and has reasonable length
    // Quantus SS58 addresses typically start with 'q' and are 47-48 characters
    if (trimmed.isEmpty) return false;
    if (trimmed.length < 40 || trimmed.length > 50) return false;
    // Check for valid base58 characters (no 0, O, I, l)
    final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    return base58Regex.hasMatch(trimmed);
  }

  /// Save just the rewards preimage directly (without mnemonic).
  ///
  /// Use this when the user has a preimage from another source (e.g., CLI)
  /// and doesn't want to import their full mnemonic.
  ///
  /// Note: Without the mnemonic, the user cannot withdraw rewards from this app.
  /// They will need to use the CLI or another tool with access to the secret.
  Future<void> savePreimageOnly(String preimage) async {
    final trimmed = preimage.trim();

    if (!validatePreimage(trimmed)) {
      throw ArgumentError('Invalid preimage format. Expected SS58-encoded address.');
    }

    // Save the preimage to file
    await _saveRewardsPreimage(trimmed);
    _log.i('Preimage saved (without mnemonic)');
  }

  /// Check if we have the full mnemonic (can withdraw) or just preimage (mining only).
  Future<bool> canWithdraw() async {
    return await hasMnemonic();
  }

  /// Delete all wallet data (for logout/reset).
  Future<void> deleteWalletData() async {
    _log.i('Deleting wallet data...');

    // Delete mnemonic from secure storage
    try {
      await _secureStorage.delete(key: _mnemonicKey);
      _log.i('Mnemonic deleted from secure storage');
    } catch (e) {
      _log.e('Error deleting mnemonic', error: e);
    }

    // Delete rewards preimage file
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final preimageFile = File('$quantusHome/$_rewardsPreimageFileName');
      if (await preimageFile.exists()) {
        await preimageFile.delete();
        _log.i('Rewards preimage file deleted');
      }
    } catch (e) {
      _log.e('Error deleting rewards preimage file', error: e);
    }

    // Delete legacy rewards address file
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final legacyFile = File('$quantusHome/$_legacyRewardsAddressFileName');
      if (await legacyFile.exists()) {
        await legacyFile.delete();
        _log.i('Legacy rewards address file deleted');
      }
    } catch (e) {
      _log.e('Error deleting legacy rewards address file', error: e);
    }
  }

  /// Check if the setup is complete (either new preimage file or legacy address file exists).
  Future<bool> isSetupComplete() async {
    // Check for new preimage file first
    if (await hasRewardsPreimageFile()) {
      return true;
    }

    // Fall back to checking legacy file for backward compatibility
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final legacyFile = File('$quantusHome/$_legacyRewardsAddressFileName');
      return await legacyFile.exists();
    } catch (e) {
      return false;
    }
  }
}
