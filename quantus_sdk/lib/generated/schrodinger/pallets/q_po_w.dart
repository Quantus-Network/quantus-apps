// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/primitive_types/u512.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<BigInt> _lastBlockTime = const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'LastBlockTime',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<BigInt> _lastBlockDuration = const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'LastBlockDuration',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<_i3.U512> _currentDistanceThreshold = const _i1.StorageValue<_i3.U512>(
    prefix: 'QPoW',
    storage: 'CurrentDistanceThreshold',
    valueCodec: _i3.U512Codec(),
  );

  final _i1.StorageValue<_i3.U512> _totalWork = const _i1.StorageValue<_i3.U512>(
    prefix: 'QPoW',
    storage: 'TotalWork',
    valueCodec: _i3.U512Codec(),
  );

  final _i1.StorageValue<int> _blocksInPeriod = const _i1.StorageValue<int>(
    prefix: 'QPoW',
    storage: 'BlocksInPeriod',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageMap<int, BigInt> _blockTimeHistory = const _i1.StorageMap<int, BigInt>(
    prefix: 'QPoW',
    storage: 'BlockTimeHistory',
    valueCodec: _i2.U64Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageValue<int> _historyIndex = const _i1.StorageValue<int>(
    prefix: 'QPoW',
    storage: 'HistoryIndex',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageValue<BigInt> _blockTimeEma = const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'BlockTimeEma',
    valueCodec: _i2.U64Codec.codec,
  );

  _i4.Future<BigInt> lastBlockTime({_i1.BlockHash? at}) async {
    final hashedKey = _lastBlockTime.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _lastBlockTime.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i4.Future<BigInt> lastBlockDuration({_i1.BlockHash? at}) async {
    final hashedKey = _lastBlockDuration.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _lastBlockDuration.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i4.Future<_i3.U512> currentDistanceThreshold({_i1.BlockHash? at}) async {
    final hashedKey = _currentDistanceThreshold.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _currentDistanceThreshold.decodeValue(bytes);
    }
    return List<BigInt>.filled(8, BigInt.zero, growable: false); /* Default */
  }

  _i4.Future<_i3.U512> totalWork({_i1.BlockHash? at}) async {
    final hashedKey = _totalWork.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _totalWork.decodeValue(bytes);
    }
    return List<BigInt>.filled(8, BigInt.zero, growable: false); /* Default */
  }

  _i4.Future<int> blocksInPeriod({_i1.BlockHash? at}) async {
    final hashedKey = _blocksInPeriod.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _blocksInPeriod.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  _i4.Future<BigInt> blockTimeHistory(int key1, {_i1.BlockHash? at}) async {
    final hashedKey = _blockTimeHistory.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _blockTimeHistory.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i4.Future<int> historyIndex({_i1.BlockHash? at}) async {
    final hashedKey = _historyIndex.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _historyIndex.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  _i4.Future<BigInt> blockTimeEma({_i1.BlockHash? at}) async {
    final hashedKey = _blockTimeEma.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _blockTimeEma.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i4.Future<List<BigInt>> multiBlockTimeHistory(List<int> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _blockTimeHistory.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _blockTimeHistory.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => BigInt.zero).toList() as List<BigInt>); /* Default */
  }

  /// Returns the storage key for `lastBlockTime`.
  _i5.Uint8List lastBlockTimeKey() {
    final hashedKey = _lastBlockTime.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `lastBlockDuration`.
  _i5.Uint8List lastBlockDurationKey() {
    final hashedKey = _lastBlockDuration.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `currentDistanceThreshold`.
  _i5.Uint8List currentDistanceThresholdKey() {
    final hashedKey = _currentDistanceThreshold.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `totalWork`.
  _i5.Uint8List totalWorkKey() {
    final hashedKey = _totalWork.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blocksInPeriod`.
  _i5.Uint8List blocksInPeriodKey() {
    final hashedKey = _blocksInPeriod.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blockTimeHistory`.
  _i5.Uint8List blockTimeHistoryKey(int key1) {
    final hashedKey = _blockTimeHistory.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `historyIndex`.
  _i5.Uint8List historyIndexKey() {
    final hashedKey = _historyIndex.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blockTimeEma`.
  _i5.Uint8List blockTimeEmaKey() {
    final hashedKey = _blockTimeEma.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `blockTimeHistory`.
  _i5.Uint8List blockTimeHistoryMapPrefix() {
    final hashedKey = _blockTimeHistory.mapPrefix();
    return hashedKey;
  }
}

class Constants {
  Constants();

  /// Pallet's weight info
  final int initialDistanceThresholdExponent = 496;

  final int difficultyAdjustPercentClamp = 10;

  final BigInt targetBlockTime = BigInt.from(12000);

  /// EMA smoothing factor (0-1000, where 1000 = 1.0)
  final int emaAlpha = 500;

  final int maxReorgDepth = 180;

  /// Fixed point scale for calculations (default: 10^18)
  final BigInt fixedU128Scale = BigInt.parse('1000000000000000000', radix: 10);

  /// Maximum distance threshold multiplier (default: 4)
  final int maxDistanceMultiplier = 2;
}
