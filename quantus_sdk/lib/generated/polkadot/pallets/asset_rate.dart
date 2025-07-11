// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;

import '../types/pallet_asset_rate/pallet/call.dart' as _i7;
import '../types/polkadot_runtime/runtime_call.dart' as _i6;
import '../types/polkadot_runtime_common/impls/versioned_locatable_asset.dart'
    as _i2;
import '../types/sp_arithmetic/fixed_point/fixed_u128.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.VersionedLocatableAsset, _i3.FixedU128>
      _conversionRateToNative =
      const _i1.StorageMap<_i2.VersionedLocatableAsset, _i3.FixedU128>(
    prefix: 'AssetRate',
    storage: 'ConversionRateToNative',
    valueCodec: _i3.FixedU128Codec(),
    hasher:
        _i1.StorageHasher.blake2b128Concat(_i2.VersionedLocatableAsset.codec),
  );

  /// Maps an asset to its fixed point representation in the native balance.
  ///
  /// E.g. `native_amount = asset_amount * ConversionRateToNative::<T>::get(asset_kind)`
  _i4.Future<_i3.FixedU128?> conversionRateToNative(
    _i2.VersionedLocatableAsset key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _conversionRateToNative.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _conversionRateToNative.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Maps an asset to its fixed point representation in the native balance.
  ///
  /// E.g. `native_amount = asset_amount * ConversionRateToNative::<T>::get(asset_kind)`
  _i4.Future<List<_i3.FixedU128?>> multiConversionRateToNative(
    List<_i2.VersionedLocatableAsset> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _conversionRateToNative.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _conversionRateToNative.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `conversionRateToNative`.
  _i5.Uint8List conversionRateToNativeKey(_i2.VersionedLocatableAsset key1) {
    final hashedKey = _conversionRateToNative.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `conversionRateToNative`.
  _i5.Uint8List conversionRateToNativeMapPrefix() {
    final hashedKey = _conversionRateToNative.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Initialize a conversion rate to native balance for the given asset.
  ///
  /// ## Complexity
  /// - O(1)
  _i6.AssetRate create({
    required _i2.VersionedLocatableAsset assetKind,
    required _i3.FixedU128 rate,
  }) {
    return _i6.AssetRate(_i7.Create(
      assetKind: assetKind,
      rate: rate,
    ));
  }

  /// Update the conversion rate to native balance for the given asset.
  ///
  /// ## Complexity
  /// - O(1)
  _i6.AssetRate update({
    required _i2.VersionedLocatableAsset assetKind,
    required _i3.FixedU128 rate,
  }) {
    return _i6.AssetRate(_i7.Update(
      assetKind: assetKind,
      rate: rate,
    ));
  }

  /// Remove an existing conversion rate to native balance for the given asset.
  ///
  /// ## Complexity
  /// - O(1)
  _i6.AssetRate remove({required _i2.VersionedLocatableAsset assetKind}) {
    return _i6.AssetRate(_i7.Remove(assetKind: assetKind));
  }
}
