// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/primitive_types/u512.dart' as _i3;
import '../types/sp_arithmetic/fixed_point/fixed_u128.dart' as _i6;

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

  final _i1.StorageValue<_i3.U512> _currentDifficulty = const _i1.StorageValue<_i3.U512>(
    prefix: 'QPoW',
    storage: 'CurrentDifficulty',
    valueCodec: _i3.U512Codec(),
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

  _i4.Future<_i3.U512> currentDifficulty({_i1.BlockHash? at}) async {
    final hashedKey = _currentDifficulty.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _currentDifficulty.decodeValue(bytes);
    }
    return List<BigInt>.filled(8, BigInt.zero, growable: false); /* Default */
  }

  _i4.Future<BigInt> blockTimeEma({_i1.BlockHash? at}) async {
    final hashedKey = _blockTimeEma.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _blockTimeEma.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
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

  /// Returns the storage key for `currentDifficulty`.
  _i5.Uint8List currentDifficultyKey() {
    final hashedKey = _currentDifficulty.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `blockTimeEma`.
  _i5.Uint8List blockTimeEmaKey() {
    final hashedKey = _blockTimeEma.hashedKey();
    return hashedKey;
  }
}

class Constants {
  Constants();

  /// Pallet's weight info
  final _i3.U512 initialDifficulty = <BigInt>[
    BigInt.from(1189189),
    BigInt.from(0),
    BigInt.from(0),
    BigInt.from(0),
    BigInt.from(0),
    BigInt.from(0),
    BigInt.from(0),
    BigInt.from(0),
  ];

  final _i6.FixedU128 difficultyAdjustPercentClamp = BigInt.parse('100000000000000000', radix: 10);

  final BigInt targetBlockTime = BigInt.from(12000);

  /// EMA smoothing factor (0-1000, where 1000 = 1.0)
  final int emaAlpha = 100;

  final int maxReorgDepth = 180;
}
