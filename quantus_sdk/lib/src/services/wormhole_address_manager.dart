import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';

/// Purpose values for wormhole HD derivation.
class WormholeAddressPurpose {
  /// Change addresses for wormhole withdrawals.
  static const int change = 0;

  /// Miner rewards (primary address).
  static const int minerRewards = 1;
}

/// Information about a tracked wormhole address.
class TrackedWormholeAddress {
  /// The wormhole address (SS58 format).
  final String address;

  /// The HD derivation purpose.
  final int purpose;

  /// The HD derivation index.
  final int index;

  /// The secret for this address (hex encoded, needed for proofs).
  final String secretHex;

  /// Whether this is the primary miner rewards address.
  bool get isPrimary => purpose == WormholeAddressPurpose.minerRewards && index == 0;

  const TrackedWormholeAddress({
    required this.address,
    required this.purpose,
    required this.index,
    required this.secretHex,
  });

  Map<String, dynamic> toJson() => {'address': address, 'purpose': purpose, 'index': index, 'secretHex': secretHex};

  factory TrackedWormholeAddress.fromJson(Map<String, dynamic> json) {
    return TrackedWormholeAddress(
      address: json['address'] as String,
      purpose: json['purpose'] as int,
      index: json['index'] as int,
      secretHex: json['secretHex'] as String,
    );
  }

  @override
  String toString() => 'TrackedWormholeAddress($address, purpose=$purpose, index=$index)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackedWormholeAddress && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}

/// Callback supplying the wallet mnemonic (or null if none).
typedef MnemonicGetter = Future<String?> Function();

/// Manages multiple wormhole addresses for a wallet.
///
/// Tracks the primary miner rewards address (purpose=1, index=0) and any
/// change addresses generated during partial withdrawals (purpose=0, index=N).
/// All addresses are derived from the same mnemonic using HD derivation.
class WormholeAddressManager {
  static const String _storageFileName = 'wormhole_addresses.json';

  final MnemonicGetter _getMnemonic;
  final HdWalletService _hdWalletService;
  final String? _customStorageDir;

  final Map<String, TrackedWormholeAddress> _addresses = {};
  int _nextChangeIndex = 0;

  WormholeAddressManager({required MnemonicGetter getMnemonic, HdWalletService? hdWalletService, String? storageDir})
    : _getMnemonic = getMnemonic,
      _hdWalletService = hdWalletService ?? HdWalletService(),
      _customStorageDir = storageDir;

  List<TrackedWormholeAddress> get allAddresses => _addresses.values.toList();
  Set<String> get allAddressStrings => _addresses.keys.toSet();

  TrackedWormholeAddress? get primaryAddress => _addresses.values.where((a) => a.isPrimary).firstOrNull;

  TrackedWormholeAddress? getAddress(String address) => _addresses[address];
  bool isTracked(String address) => _addresses.containsKey(address);

  /// Load from disk and ensure the primary address is tracked.
  Future<void> initialize() async {
    await _loadFromDisk();
    final mnemonic = await _getMnemonic();
    if (mnemonic != null) {
      await _ensurePrimaryAddressTracked(mnemonic);
    }
  }

  Future<void> _ensurePrimaryAddressTracked(String mnemonic) async {
    final keyPair = _hdWalletService.deriveMinerRewardsKeyPair(mnemonic: mnemonic, index: 0);
    if (!_addresses.containsKey(keyPair.address)) {
      _addresses[keyPair.address] = TrackedWormholeAddress(
        address: keyPair.address,
        purpose: WormholeAddressPurpose.minerRewards,
        index: 0,
        secretHex: keyPair.secretHex,
      );
      await _saveToDisk();
    }
  }

  /// Derive and track a new change address. Returns the new address.
  Future<TrackedWormholeAddress> deriveNextChangeAddress() async {
    final mnemonic = await _getMnemonic();
    if (mnemonic == null) {
      throw StateError('No mnemonic available - cannot derive change address');
    }

    final keyPair = _hdWalletService.deriveWormholeKeyPair(
      mnemonic: mnemonic,
      purpose: WormholeAddressPurpose.change,
      index: _nextChangeIndex,
    );

    final tracked = TrackedWormholeAddress(
      address: keyPair.address,
      purpose: WormholeAddressPurpose.change,
      index: _nextChangeIndex,
      secretHex: keyPair.secretHex,
    );

    _addresses[keyPair.address] = tracked;
    _nextChangeIndex++;
    await _saveToDisk();
    return tracked;
  }

  /// Re-derive all addresses from the mnemonic (for restore/re-sync).
  Future<void> rederiveAllSecrets() async {
    final mnemonic = await _getMnemonic();
    if (mnemonic == null) return;

    final updated = <String, TrackedWormholeAddress>{};
    for (final tracked in _addresses.values) {
      final keyPair = _hdWalletService.deriveWormholeKeyPair(
        mnemonic: mnemonic,
        purpose: tracked.purpose,
        index: tracked.index,
      );
      if (keyPair.address != tracked.address) continue;
      updated[keyPair.address] = TrackedWormholeAddress(
        address: keyPair.address,
        purpose: tracked.purpose,
        index: tracked.index,
        secretHex: keyPair.secretHex,
      );
    }

    _addresses
      ..clear()
      ..addAll(updated);
    await _saveToDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _getStorageFile();
      if (!await file.exists()) return;

      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _addresses.clear();
      final addressesData = data['addresses'] as List<dynamic>?;
      if (addressesData != null) {
        for (final item in addressesData) {
          final tracked = TrackedWormholeAddress.fromJson(item as Map<String, dynamic>);
          _addresses[tracked.address] = tracked;
        }
      }
      _nextChangeIndex = data['nextChangeIndex'] as int? ?? 0;
    } catch (_) {
      // Silently fail - addresses will be re-derived if needed
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getStorageFile();
      final data = {
        'nextChangeIndex': _nextChangeIndex,
        'addresses': _addresses.values.map((a) => a.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Silently fail - not critical
    }
  }

  Future<File> _getStorageFile() async {
    final basePath = _customStorageDir ?? (await getApplicationSupportDirectory()).path;
    final quantusDir = Directory('$basePath/.quantus');
    if (!await quantusDir.exists()) {
      await quantusDir.create(recursive: true);
    }
    return File('${quantusDir.path}/$_storageFileName');
  }

  /// Clear all tracked addresses (for reset/logout).
  Future<void> clearAll() async {
    _addresses.clear();
    _nextChangeIndex = 0;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Silently fail
    }
  }
}
