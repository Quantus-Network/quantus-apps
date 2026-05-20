import 'dart:io';
import 'dart:math';

import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('MinerWallet');

/// Miner wallet: rewards preimage persisted on disk.
///
/// Two setup flows are supported:
/// - Full: mnemonic is stored via the SDK secure storage and the rewards preimage
///   is saved on disk.
/// - Preimage-only: only the rewards preimage file is written. The node can mine
///   but the user must withdraw via CLI.
class MinerWalletService {
  static final MinerWalletService _instance = MinerWalletService._internal();
  factory MinerWalletService() => _instance;

  static const String _rewardsPreimageFileName = 'rewards-preimage.txt';
  static const String _legacyRewardsAddressFileName = 'rewards-address.txt';
  static const int _minerWalletIndex = 0;

  final HdWalletService _hdWallet = HdWalletService();
  final SettingsService _settings = SettingsService();

  MinerWalletService._internal();

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

  /// Normalize user-entered mnemonic input: lowercase + collapse whitespace.
  /// The BIP-39 English wordlist is lowercase only.
  String normalizeMnemonic(String mnemonic) => mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  bool validateMnemonic(String mnemonic) {
    try {
      Mnemonic.fromSentence(normalizeMnemonic(mnemonic), Language.english);
      return true;
    } catch (e) {
      _log.w('Invalid mnemonic: $e');
      return false;
    }
  }

  /// Returns words that are not in the BIP-39 English wordlist, with their
  /// 1-based positions. Useful for telling the user which word(s) are typos.
  List<({int position, String word})> findInvalidMnemonicWords(String mnemonic) {
    final words = normalizeMnemonic(mnemonic).split(' ');
    final invalid = <({int position, String word})>[];
    for (var i = 0; i < words.length; i++) {
      if (words[i].isEmpty) continue;
      if (!Language.english.isValid(words[i])) {
        invalid.add((position: i + 1, word: words[i]));
      }
    }
    return invalid;
  }

  /// Save the mnemonic via SDK secure storage and persist the rewards preimage.
  Future<WormholeKeyPair> saveMnemonic(String mnemonic) async {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    final normalized = normalizeMnemonic(mnemonic);
    await _settings.setMnemonic(normalized, _minerWalletIndex);
    _log.i('Mnemonic saved securely via SDK settings');

    final keyPair = _hdWallet.deriveWormholeKeyPair(mnemonic: normalized);
    await _saveRewardsPreimage(keyPair.rewardsPreimage);

    _log.i('Wormhole address derived: ${keyPair.address}');
    return keyPair;
  }

  Future<String?> getMnemonic() => _settings.getMnemonic(_minerWalletIndex);

  Future<bool> hasMnemonic() async {
    final mnemonic = await getMnemonic();
    return mnemonic != null && mnemonic.isNotEmpty;
  }

  /// Wormhole key pair derived from the stored mnemonic, or reconstructed from
  /// stored preimage data when only mining is configured.
  Future<WormholeKeyPair?> getWormholeKeyPair() async {
    final mnemonic = await getMnemonic();
    if (mnemonic != null && mnemonic.isNotEmpty) {
      return _hdWallet.deriveWormholeKeyPair(mnemonic: mnemonic);
    }

    final preimage = await readRewardsPreimageFile();
    if (preimage == null || preimage.isEmpty) return null;
    final rewardsPreimageHex = _hdWallet.preimageSs58ToHex(preimage);
    final address = _hdWallet.preimageToAddress(rewardsPreimageHex);
    return WormholeKeyPair(
      address: address,
      addressHex: '',
      rewardsPreimage: preimage,
      rewardsPreimageHex: rewardsPreimageHex,
      secretHex: '',
    );
  }

  /// Hex value for the node's `--rewards-inner-hash` flag.
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
      await _settings.deleteMnemonic(_minerWalletIndex);
      _log.i('Mnemonic deleted from SDK secure storage');
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
