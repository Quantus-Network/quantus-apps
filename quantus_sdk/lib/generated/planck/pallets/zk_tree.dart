// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i3;

import '../types/pallet_zk_tree/zk_leaf.dart' as _i2;
import '../types/tuples.dart' as _i4;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<BigInt, _i2.ZkLeaf> _leaves = const _i1.StorageMap<BigInt, _i2.ZkLeaf>(
    prefix: 'ZkTree',
    storage: 'Leaves',
    valueCodec: _i2.ZkLeaf.codec,
    hasher: _i1.StorageHasher.identity(_i3.U64Codec.codec),
  );

  final _i1.StorageMap<_i4.Tuple2<int, BigInt>, List<int>> _nodes =
      const _i1.StorageMap<_i4.Tuple2<int, BigInt>, List<int>>(
        prefix: 'ZkTree',
        storage: 'Nodes',
        valueCodec: _i3.U8ArrayCodec(32),
        hasher: _i1.StorageHasher.identity(_i4.Tuple2Codec<int, BigInt>(_i3.U8Codec.codec, _i3.U64Codec.codec)),
      );

  final _i1.StorageValue<BigInt> _leafCount = const _i1.StorageValue<BigInt>(
    prefix: 'ZkTree',
    storage: 'LeafCount',
    valueCodec: _i3.U64Codec.codec,
  );

  final _i1.StorageValue<int> _depth = const _i1.StorageValue<int>(
    prefix: 'ZkTree',
    storage: 'Depth',
    valueCodec: _i3.U8Codec.codec,
  );

  final _i1.StorageValue<List<int>> _root = const _i1.StorageValue<List<int>>(
    prefix: 'ZkTree',
    storage: 'Root',
    valueCodec: _i3.U8ArrayCodec(32),
  );

  /// Leaf data stored by index.
  _i5.Future<_i2.ZkLeaf?> leaves(BigInt key1, {_i1.BlockHash? at}) async {
    final hashedKey = _leaves.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _leaves.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Internal tree nodes: (level, index) -> hash.
  /// Level 0 is unused (leaves are hashed on-demand).
  /// Level 1+ contains internal node hashes.
  _i5.Future<List<int>?> nodes(_i4.Tuple2<int, BigInt> key1, {_i1.BlockHash? at}) async {
    final hashedKey = _nodes.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _nodes.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Number of leaves in the tree.
  _i5.Future<BigInt> leafCount({_i1.BlockHash? at}) async {
    final hashedKey = _leafCount.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _leafCount.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Current depth of the tree (0 = empty, 1 = up to 4 leaves, etc.).
  _i5.Future<int> depth({_i1.BlockHash? at}) async {
    final hashedKey = _depth.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _depth.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Current root hash of the tree.
  _i5.Future<List<int>> root({_i1.BlockHash? at}) async {
    final hashedKey = _root.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _root.decodeValue(bytes);
    }
    return List<int>.filled(32, 0, growable: false); /* Default */
  }

  /// Leaf data stored by index.
  _i5.Future<List<_i2.ZkLeaf?>> multiLeaves(List<BigInt> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _leaves.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _leaves.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Internal tree nodes: (level, index) -> hash.
  /// Level 0 is unused (leaves are hashed on-demand).
  /// Level 1+ contains internal node hashes.
  _i5.Future<List<List<int>?>> multiNodes(List<_i4.Tuple2<int, BigInt>> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _nodes.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _nodes.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `leaves`.
  _i6.Uint8List leavesKey(BigInt key1) {
    final hashedKey = _leaves.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `nodes`.
  _i6.Uint8List nodesKey(_i4.Tuple2<int, BigInt> key1) {
    final hashedKey = _nodes.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `leafCount`.
  _i6.Uint8List leafCountKey() {
    final hashedKey = _leafCount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `depth`.
  _i6.Uint8List depthKey() {
    final hashedKey = _depth.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `root`.
  _i6.Uint8List rootKey() {
    final hashedKey = _root.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `leaves`.
  _i6.Uint8List leavesMapPrefix() {
    final hashedKey = _leaves.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `nodes`.
  _i6.Uint8List nodesMapPrefix() {
    final hashedKey = _nodes.mapPrefix();
    return hashedKey;
  }
}
