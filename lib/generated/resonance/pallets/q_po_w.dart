// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<int, BigInt> _blockDifficulties =
      const _i1.StorageMap<int, BigInt>(
    prefix: 'QPoW',
    storage: 'BlockDifficulties',
    valueCodec: _i2.U64Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageValue<List<int>> _latestNonce =
      const _i1.StorageValue<List<int>>(
    prefix: 'QPoW',
    storage: 'LatestNonce',
    valueCodec: _i2.U8ArrayCodec(64),
  );

  final _i1.StorageValue<BigInt> _lastBlockTime =
      const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'LastBlockTime',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<BigInt> _lastBlockDuration =
      const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'LastBlockDuration',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<BigInt> _currentDifficulty =
      const _i1.StorageValue<BigInt>(
    prefix: 'QPoW',
    storage: 'CurrentDifficulty',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<int> _blocksInPeriod = const _i1.StorageValue<int>(
    prefix: 'QPoW',
    storage: 'BlocksInPeriod',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageMap<int, BigInt> _blockTimeHistory =
      const _i1.StorageMap<int, BigInt>(
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

  final _i1.StorageValue<int> _historySize = const _i1.StorageValue<int>(
    prefix: 'QPoW',
    storage: 'HistorySize',
    valueCodec: _i2.U32Codec.codec,
  );

  _i3.Future<BigInt> blockDifficulties(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _blockDifficulties.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _blockDifficulties.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i3.Future<List<int>?> latestNonce({_i1.BlockHash? at}) async {
    final hashedKey = _latestNonce.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _latestNonce.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  _i3.Future<BigInt> lastBlockTime({_i1.BlockHash? at}) async {
    final hashedKey = _lastBlockTime.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _lastBlockTime.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i3.Future<BigInt> lastBlockDuration({_i1.BlockHash? at}) async {
    final hashedKey = _lastBlockDuration.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _lastBlockDuration.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i3.Future<BigInt> currentDifficulty({_i1.BlockHash? at}) async {
    final hashedKey = _currentDifficulty.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _currentDifficulty.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i3.Future<int> blocksInPeriod({_i1.BlockHash? at}) async {
    final hashedKey = _blocksInPeriod.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _blocksInPeriod.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  _i3.Future<BigInt> blockTimeHistory(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _blockTimeHistory.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _blockTimeHistory.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i3.Future<int> historyIndex({_i1.BlockHash? at}) async {
    final hashedKey = _historyIndex.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _historyIndex.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  _i3.Future<int> historySize({_i1.BlockHash? at}) async {
    final hashedKey = _historySize.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _historySize.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Returns the storage key for `blockDifficulties`.
  _i4.Uint8List blockDifficultiesKey(int key1) {
    final hashedKey = _blockDifficulties.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `latestNonce`.
  _i4.Uint8List latestNonceKey() {
    final hashedKey = _latestNonce.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `lastBlockTime`.
  _i4.Uint8List lastBlockTimeKey() {
    final hashedKey = _lastBlockTime.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `lastBlockDuration`.
  _i4.Uint8List lastBlockDurationKey() {
    final hashedKey = _lastBlockDuration.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `currentDifficulty`.
  _i4.Uint8List currentDifficultyKey() {
    final hashedKey = _currentDifficulty.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blocksInPeriod`.
  _i4.Uint8List blocksInPeriodKey() {
    final hashedKey = _blocksInPeriod.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blockTimeHistory`.
  _i4.Uint8List blockTimeHistoryKey(int key1) {
    final hashedKey = _blockTimeHistory.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `historyIndex`.
  _i4.Uint8List historyIndexKey() {
    final hashedKey = _historyIndex.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `historySize`.
  _i4.Uint8List historySizeKey() {
    final hashedKey = _historySize.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `blockDifficulties`.
  _i4.Uint8List blockDifficultiesMapPrefix() {
    final hashedKey = _blockDifficulties.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `blockTimeHistory`.
  _i4.Uint8List blockTimeHistoryMapPrefix() {
    final hashedKey = _blockTimeHistory.mapPrefix();
    return hashedKey;
  }
}

class Constants {
  Constants();

  final BigInt initialDifficulty = BigInt.from(5500000000);

  final BigInt minDifficulty = BigInt.from(50000000000);

  final BigInt targetBlockTime = BigInt.from(1000);

  final int adjustmentPeriod = 10;

  final BigInt dampeningFactor = BigInt.from(8);

  final int blockTimeHistorySize = 60;
}
