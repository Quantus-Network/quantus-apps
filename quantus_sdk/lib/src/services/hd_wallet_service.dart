import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:ss58/ss58.dart';

import '../rust/api/crypto.dart' as crypto;
import '../rust/api/wormhole.dart' as wormhole_ffi;

/// A wormhole commitment chain: `secret -> first_hash = poseidon(salt || secret) -> address = poseidon(first_hash)`.
///
/// Funds are claimed either by revealing [rewardsPreimageHex] (miner rewards) or by
/// producing a ZK proof that knows [secretHex] (withdrawals). [secretHex] is empty
/// when the pair was reconstructed from a raw preimage.
///
/// [secretHex] is spendable key material held as an immutable Dart String, so
/// it cannot be zeroized — never cache key pairs; derive, use immediately, and
/// let them go out of scope (M11).
class WormholeKeyPair {
  final String address;
  final String addressHex;
  final String rewardsPreimageHex;
  final String secretHex;

  const WormholeKeyPair({
    required this.address,
    required this.addressHex,
    required this.rewardsPreimageHex,
    required this.secretHex,
  });

  factory WormholeKeyPair.fromResult(crypto.WormholeResult result) {
    final addressBytes = Address.decode(result.address).pubkey;
    return WormholeKeyPair(
      address: result.address,
      addressHex: '0x${hex.encode(addressBytes)}',
      rewardsPreimageHex: '0x${hex.encode(result.firstHash)}',
      secretHex: '0x${hex.encode(result.secret)}',
    );
  }
}

class HdWalletService {
  // Dev accounts (//Crystal Alice etc.) derive from publicly known seeds, so
  // they are only importable in debug builds (M8).
  static const _devAccounts = {
    AppConstants.crystalAlice: crypto.crystalAlice,
    AppConstants.crystalBob: crypto.crystalBob,
    AppConstants.crystalCharlie: crypto.crystalCharlie,
  };

  static bool isDevAccount(String mnemonic) => kDebugMode && _devAccounts.containsKey(mnemonic);

  /// Transparent-account path. The account level carries the index; the trailing
  /// address index carries the scheme (`0'` for ML-DSA-87, `1'` for ML-DSA-65), as in quantus-cli.
  static String pathForIndex(int account, DilithiumScheme scheme) =>
      "m/44'/189189'/$account'/0'/${scheme.derivationAddressIndex}'";

  static final RegExp _pathPattern = RegExp(r"^m(/\d+'?)+$");

  static bool isValidPath(String path) => _pathPattern.hasMatch(path.trim());

  Keypair keyPairAtPath(String mnemonic, String path, DilithiumScheme scheme) {
    if (kDebugMode) {
      final devKeypair = _devAccounts[mnemonic];
      if (devKeypair != null) return devKeypair();
    }
    final trimmed = path.trim();
    if (!isValidPath(trimmed)) throw FormatException('Not a derivation path: $path');
    return crypto.generateDerivedKeypair(mnemonicStr: mnemonic, path: trimmed, scheme: scheme);
  }

  Keypair keyPairAtIndex(String mnemonic, int index, DilithiumScheme scheme) =>
      keyPairAtPath(mnemonic, pathForIndex(index, scheme), scheme);

  crypto.WormholeResult _deriveWormhole(String mnemonic, {int account = 0, int change = 0, int addressIndex = 0}) {
    final path = "m/44'/189189189'/$account'/$change'/$addressIndex'";
    return crypto.deriveWormhole(mnemonicStr: mnemonic, path: path);
  }

  /// Derive the wormhole key pair at HD index `index` (account=0, change=0).
  WormholeKeyPair deriveWormholeKeyPair({required String mnemonic, int index = 0}) =>
      WormholeKeyPair.fromResult(_deriveWormhole(mnemonic, addressIndex: index));

  WormholeKeyPair deriveWormholeChangeAddressKeyPair({required String mnemonic, int index = 0}) =>
      WormholeKeyPair.fromResult(_deriveWormhole(mnemonic, change: 1, addressIndex: index));

  /// Compute the on-chain wormhole address for a rewards preimage (first_hash hex).
  String preimageToAddress(String preimageHex) => crypto.firstHashToAddress(firstHashHex: preimageHex);

  /// Normalize a rewards preimage to the `0x…` hex form consumed by the node's
  /// `--rewards-inner-hash` flag. Accepts a 64-character hex string (with or
  /// without `0x`) or the legacy SS58-encoded form. Returns null if invalid.
  String? normalizePreimageToHex(String preimage) {
    final trimmed = preimage.trim();
    final hexMatch = RegExp(r'^(0x)?([0-9a-fA-F]{64})$').firstMatch(trimmed);
    if (hexMatch != null) return '0x${hexMatch.group(2)!.toLowerCase()}';
    try {
      final pubkey = Address.decode(trimmed).pubkey;
      if (pubkey.length != 32) return null;
      return '0x${hex.encode(pubkey)}';
    } catch (_) {
      return null;
    }
  }

  bool validatePreimage(String preimage) => normalizePreimageToHex(preimage) != null;

  String computeNullifier({required String secretHex, required BigInt transferCount}) {
    final secretBytes = hex.decode(secretHex.replaceFirst('0x', ''));
    final nullifierBytes = wormhole_ffi.computeNullifier(secret: secretBytes, transferCount: transferCount);
    return '0x${hex.encode(nullifierBytes)}';
  }
}
