// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_wormhole/pallet/call.dart' as _i6;
import '../types/quantus_runtime/runtime_call.dart' as _i5;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<List<int>, bool> _usedNullifiers =
      const _i1.StorageMap<List<int>, bool>(
    prefix: 'Wormhole',
    storage: 'UsedNullifiers',
    valueCodec: _i2.BoolCodec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U8ArrayCodec(64)),
  );

  _i3.Future<bool> usedNullifiers(
    List<int> key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _usedNullifiers.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _usedNullifiers.decodeValue(bytes);
    }
    return false; /* Default */
  }

  /// Returns the storage key for `usedNullifiers`.
  _i4.Uint8List usedNullifiersKey(List<int> key1) {
    final hashedKey = _usedNullifiers.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `usedNullifiers`.
  _i4.Uint8List usedNullifiersMapPrefix() {
    final hashedKey = _usedNullifiers.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  _i5.Wormhole verifyWormholeProof({required List<int> proofBytes}) {
    return _i5.Wormhole(_i6.VerifyWormholeProof(proofBytes: proofBytes));
  }
}
