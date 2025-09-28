// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/frame_support/traits/tokens/misc/id_amount_1.dart' as _i3;
import '../types/sp_core/crypto/account_id32.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageDoubleMap<int, _i2.AccountId32, List<_i3.IdAmount>> _holds =
      const _i1.StorageDoubleMap<int, _i2.AccountId32, List<_i3.IdAmount>>(
    prefix: 'AssetsHolder',
    storage: 'Holds',
    valueCodec: _i4.SequenceCodec<_i3.IdAmount>(_i3.IdAmount.codec),
    hasher1: _i1.StorageHasher.blake2b128Concat(_i4.U32Codec.codec),
    hasher2: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageDoubleMap<int, _i2.AccountId32, BigInt> _balancesOnHold =
      const _i1.StorageDoubleMap<int, _i2.AccountId32, BigInt>(
    prefix: 'AssetsHolder',
    storage: 'BalancesOnHold',
    valueCodec: _i4.U128Codec.codec,
    hasher1: _i1.StorageHasher.blake2b128Concat(_i4.U32Codec.codec),
    hasher2: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  /// A map that stores holds applied on an account for a given AssetId.
  _i5.Future<List<_i3.IdAmount>> holds(
    int key1,
    _i2.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _holds.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _holds.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// A map that stores the current total balance on hold for every account on a given AssetId.
  _i5.Future<BigInt?> balancesOnHold(
    int key1,
    _i2.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _balancesOnHold.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _balancesOnHold.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Returns the storage key for `holds`.
  _i6.Uint8List holdsKey(
    int key1,
    _i2.AccountId32 key2,
  ) {
    final hashedKey = _holds.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `balancesOnHold`.
  _i6.Uint8List balancesOnHoldKey(
    int key1,
    _i2.AccountId32 key2,
  ) {
    final hashedKey = _balancesOnHold.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage map key prefix for `holds`.
  _i6.Uint8List holdsMapPrefix(int key1) {
    final hashedKey = _holds.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `balancesOnHold`.
  _i6.Uint8List balancesOnHoldMapPrefix(int key1) {
    final hashedKey = _balancesOnHold.mapPrefix(key1);
    return hashedKey;
  }
}
